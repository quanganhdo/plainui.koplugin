-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local Preview = require("modules.reader.navigation_preview")
local Screen = require("device").screen
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local ToolbarStyle = require("modules.shared.toolbar_style")
local UIManager = require("ui/uimanager")
local T = require("ffi/util").template
local _ = require("gettext")

local BottomNavigation = InputContainer:extend{
    name = "plainui_bottom_navigation",
    covers_fullscreen = true,
    stop_events_propagation = true,
}

function BottomNavigation:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    local function scale(n) return Screen:scaleBySize(n) end
    self.dimen = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.padding = scale(24)
    local button_w, button_h = ToolbarStyle.button_width, ToolbarStyle.button_height
    local action_padding, button_gap = ToolbarStyle.padding, ToolbarStyle.button_gap
    self.header = Geom:new{ x = 0, y = 0, w = w, h = button_h }
    local bar_h = 2 * button_h + scale(40) + scale(32)
    self.bar = Geom:new{ x = 0, y = h - bar_h, w = w, h = bar_h }
    self.chapter_row = Geom:new{ x = 0, y = self.bar.y, w = w, h = button_h }
    self.previous_chapter_button = Geom:new{ x = action_padding, y = self.bar.y, w = button_w, h = button_h }
    self.next_chapter_button = Geom:new{ x = w - action_padding - button_w, y = self.bar.y, w = button_w, h = button_h }
    self.slider = Geom:new{ x = self.padding, y = self.chapter_row.y + self.chapter_row.h,
        w = w - 2 * self.padding, h = scale(40) }
    local actions_y = self.slider.y + self.slider.h
    self.search_button = Geom:new{ x = w - action_padding - button_w,
        y = actions_y, w = button_w, h = button_h }
    self.toc_button = Geom:new{ x = self.search_button.x - button_gap - button_w,
        y = actions_y, w = button_w, h = button_h }
    self.bookmarks_button = Geom:new{ x = self.toc_button.x - button_gap - button_w,
        y = actions_y, w = button_w, h = button_h }
    self.origin_row = Geom:new{ x = self.padding, y = actions_y,
        w = self.bookmarks_button.x - button_gap - self.padding, h = button_h }
    self.chevron = Geom:new{ x = 0, y = self.origin_row.y + self.origin_row.h,
        w = w, h = h - self.origin_row.y - self.origin_row.h }
    -- The selected page is centered between the header and bar; adjacent pages extend
    -- beyond the screen edges, like Kindle's single-page carousel.
    local card_w = math.floor(w * 0.68)
    local card_h = math.min(math.floor(h * 0.66), self.bar.y - self.header.h - scale(48))
    self.preview_rect = Geom:new{ x = math.floor((w - card_w) / 2),
        y = self.header.h + math.floor((self.bar.y - self.header.h - card_h) / 2), w = card_w, h = card_h }
    local r = self.preview_rect
    self.preview_image_rect = Geom:new{ x = r.x + scale(24), y = r.y + scale(28),
        w = r.w - scale(48), h = r.h - scale(68) }
    self.close_button = Geom:new{ x = w - scale(40), y = 0,
        w = scale(40), h = scale(40) }
    local gap = scale(16)
    self.neighbor_rects = {
        [-1] = Geom:new{ x = r.x - r.w - gap, y = r.y, w = r.w, h = r.h },
        [1] = Geom:new{ x = r.x + r.w + gap, y = r.y, w = r.w, h = r.h },
    }
    self.neighbor_visible_rects = {
        [-1] = Geom:new{ x = 0, y = r.y, w = math.max(0, r.x - gap), h = r.h },
        [1] = Geom:new{ x = r.x + r.w + gap, y = r.y,
            w = math.max(0, w - r.x - r.w - gap), h = r.h },
    }
    self.carousel_rect = Geom:new{ x = 0, y = r.y, w = w, h = r.h }
    self.neighbor_images = {}
    self.labels = {}
    self.icons = {}
    for id, file in pairs{
        previous_chapter = "player-skip-back.svg", next_chapter = "player-skip-forward.svg",
        bookmarks = "bookmark.svg", toc = "list-details.svg", search = "search.svg",
    } do
        self.icons[id] = ImageWidget:new{
            file = self.plugin.path .. "/icons/tabler/" .. file,
            width = ToolbarStyle.icon_size, height = ToolbarStyle.icon_size,
            alpha = false, is_icon = true,
        }
    end
    self.model = Preview.new{
        page = self.plugin.ui:getCurrentPage(),
        count = self.plugin.ui.document:getPageCount(),
        thumbnail = self.plugin.ui.thumbnail, manager = UIManager,
        width = self.preview_image_rect.w, height = self.preview_image_rect.h,
        changed = function()
            -- Show the selected page's empty cards immediately; each thumbnail
            -- fills its card when ready, without leaving stale pages on screen.
            self:clearImage()
            self:clearNeighborImages()
            self.image_page = nil
            self.failed = false
            UIManager:setDirty(self, "ui", self.bar)
            UIManager:setDirty(self, "ui", self.carousel_rect)
        end,
        rendered = function(tile)
            if tile then
                self:clearImage()
                self:clearNeighborImages()
                self.image_page = self.model.page
                self.image = self:newPreviewImage(tile)
            end
            self.failed = tile == nil
            UIManager:setDirty(self, "ui", self.carousel_rect)
        end,
        rendered_neighbor = function(tile, offset, page)
            if not tile then return end
            local previous = self.neighbor_images[offset]
            if previous then previous.image:free() end
            self.neighbor_images[offset] = { page = page, image = self:newPreviewImage(tile) }
            UIManager:setDirty(self, "ui", self.neighbor_visible_rects[offset])
        end,
    }
    -- Only the opening position is a saved marker; reading history belongs
    -- to the separate Back/Forward return footer.
    self.saved_pages = { self.model.origin }
    self.ges_events = {}
    for name, gesture in pairs{
        TapPlainNavigation = "tap", SwipePlainNavigation = "swipe",
        PanPlainNavigation = "pan", HoldPanPlainNavigation = "hold_pan",
        ReleasePlainNavigation = "pan_release", HoldReleasePlainNavigation = "hold_release",
        IgnorePlainNavigation = "hold", DoubleTapPlainNavigation = "double_tap",
        IgnoreMultiswipePlainNavigation = "multiswipe",
    } do
        self.ges_events[name] = { GestureRange:new{ ges = gesture, range = self.dimen } }
    end
end

function BottomNavigation:sliderPageX(page)
    local ratio = self.model.count == 1 and 0 or (page - 1) / (self.model.count - 1)
    return self.slider.x + math.floor(ratio * self.slider.w)
end

function BottomNavigation:drawCircle(bb, cx, cy, radius, color)
    for dy = -radius, radius do
        local half = math.floor(math.sqrt(radius * radius - dy * dy))
        bb:paintRect(cx - half, cy + dy, 2 * half + 1, 1, color)
    end
end

function BottomNavigation:newPreviewImage(tile)
    local image = ImageWidget:new{
        image = tile.bb:copy(), image_disposable = true,
        original_in_nightmode = false,
    }
    -- Initialize ownership so free() also works before the first paint.
    image:getSize()
    return image
end

function BottomNavigation:clearNeighborImages()
    for _, entry in pairs(self.neighbor_images) do entry.image:free() end
    self.neighbor_images = {}
end

function BottomNavigation:clearImage()
    if self.image then self.image:free(); self.image = nil end
end

function BottomNavigation:pageLabel(page, compact)
    local ui = self.plugin.ui
    local value = page
    if ui.pagemap and ui.pagemap:wantsPageLabels() then
        local label = ui.pagemap:getXPointerPageLabel(ui.document:getPageXPointer(page))
        if label and label ~= "" then value = ui.pagemap:cleanPageLabel(label) end
    end
    return T(compact and _("p%1") or _("Page %1"), value)
end

function BottomNavigation:drawText(bb, id, text, x, y, width, align, bold, font_size, row_height)
    local widget = self.labels[id]
    if not widget or widget.text ~= text then
        if widget then widget:free() end
        widget = TextWidget:new{
            text = text, face = Font:getFace("smallinfofont", font_size or 16),
            max_width = width, bold = bold,
        }
        self.labels[id] = widget
    end
    local size = widget:getSize()
    if row_height then y = y + math.floor((row_height - size.h) / 2) end
    if align == "center" then x = x + math.floor((width - size.w) / 2)
    elseif align == "right" then x = x + width - size.w end
    widget:paintTo(bb, x, y)
end

function BottomNavigation:chapterDestination(direction)
    local toc = self.plugin.ui.toc
    if not toc then return end
    if direction < 0 then return toc:getPreviousChapter(self.model.page) end
    return toc:getNextChapter(self.model.page)
end

function BottomNavigation:drawToolbarIcon(bb, id, rect, enabled)
    local icon = self.icons[id]
    icon.dim = enabled == false
    icon:paintTo(bb, rect.x + math.floor((rect.w - ToolbarStyle.icon_size) / 2),
        rect.y + math.floor((rect.h - ToolbarStyle.icon_size) / 2))
end

function BottomNavigation:paintPage(bb, rect, image)
    bb:paintRect(rect.x, rect.y, rect.w, rect.h, Blitbuffer.COLOR_WHITE)
    if image then
        local size = image:getSize()
        local inner = self.preview_image_rect
        local dx, dy = inner.x - self.preview_rect.x, inner.y - self.preview_rect.y
        image:paintTo(bb, rect.x + dx + math.floor((inner.w - size.w) / 2),
            rect.y + dy + math.floor((inner.h - size.h) / 2))
    end
    -- Draw the border after the image so all four sides remain visible.
    bb:paintBorder(rect.x, rect.y, rect.w, rect.h,
        math.max(1, Screen:scaleBySize(1)), Blitbuffer.COLOR_BLACK)
end

function BottomNavigation:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    self:drawText(bb, "feature_title", _("Page Preview"), self.padding, self.close_button.y,
        self.close_button.x - 2 * self.padding, "left", true, 18, self.close_button.h)
    for _, offset in ipairs{ -1, 1 } do
        local entry = self.neighbor_images[offset]
        local page = self.model.page + offset
        if page >= 1 and page <= self.model.count then
            self:paintPage(bb, self.neighbor_rects[offset], entry and entry.image)
        end
    end
    local r, image_rect = self.preview_rect, self.preview_image_rect
    self:paintPage(bb, r, self.image)
    if not self.image then
        self:drawText(bb, "loading", self.failed and _("Preview unavailable") or _("Loading…"),
            image_rect.x, image_rect.y + math.floor(image_rect.h / 2), image_rect.w, "center", false, 14)
    end
    local line = math.max(1, Screen:scaleBySize(1))
    local close_x = self.close_button.x + math.floor(self.close_button.w / 2)
    local close_y = self.close_button.y + math.floor(self.close_button.h / 2)
    local cross_size = Screen:scaleBySize(4)
    for d = -cross_size, cross_size do
        bb:paintRect(close_x + d, close_y + d, line, line, Blitbuffer.COLOR_BLACK)
        bb:paintRect(close_x + d, close_y - d, line, line, Blitbuffer.COLOR_BLACK)
    end
    local visible_page = self.image_page or self.model.page
    local count_label = T(_("%1 of %2"), self:pageLabel(visible_page), self.model.count)
    self:drawText(bb, "page_count", count_label, r.x, r.y + r.h - Screen:scaleBySize(32),
        r.w, "center", true, 12, Screen:scaleBySize(24))

    bb:paintRect(self.bar.x, self.bar.y, self.bar.w, self.bar.h, Blitbuffer.COLOR_WHITE)
    bb:paintRect(self.bar.x, self.bar.y, self.bar.w, line, Blitbuffer.COLOR_BLACK)
    self:drawToolbarIcon(bb, "previous_chapter", self.previous_chapter_button, self:chapterDestination(-1) ~= nil)
    self:drawToolbarIcon(bb, "next_chapter", self.next_chapter_button, self:chapterDestination(1) ~= nil)
    local toc = self.plugin.ui.toc
    local title = toc and toc:getTocTitleByPage(self.model.page) or ""
    if title == "" then title = self.plugin.ui.document:getProps().title or "" end
    local title_x = self.previous_chapter_button.x + self.previous_chapter_button.w + ToolbarStyle.button_gap
    local title_w = self.dimen.w - 2 * title_x
    self:drawText(bb, "chapter", title, title_x, self.chapter_row.y, title_w, "center", true, 16, self.chapter_row.h)

    local cy = self.slider.y + math.floor(self.slider.h / 2)
    local track_h = Screen:scaleBySize(6)
    bb:paintBorder(self.slider.x, cy - math.floor(track_h / 2), self.slider.w, track_h, line, Blitbuffer.COLOR_BLACK)
    for _, page in ipairs(self.saved_pages) do
        self:drawCircle(bb, self:sliderPageX(page), cy, Screen:scaleBySize(7), Blitbuffer.COLOR_DARK_GRAY)
    end
    local cx = self:sliderPageX(self.model.page)
    local radius = Screen:scaleBySize(12)
    self:drawCircle(bb, cx, cy, radius, Blitbuffer.COLOR_BLACK)
    local inner = radius - line
    self:drawCircle(bb, cx, cy, inner, Blitbuffer.COLOR_WHITE)
    self:drawText(bb, "origin", self.model.page ~= self.model.origin
        and T(_("Return to %1"), self:pageLabel(self.model.origin, true)) or "",
        self.origin_row.x, self.origin_row.y, self.origin_row.w, "left", true, 18, self.origin_row.h)
    self:drawToolbarIcon(bb, "bookmarks", self.bookmarks_button)
    self:drawToolbarIcon(bb, "toc", self.toc_button)
    self:drawToolbarIcon(bb, "search", self.search_button)
    -- Match the top toolbar's drag chevron, reflected vertically.
    local width, height = Screen:scaleBySize(24), Screen:scaleBySize(5)
    local left = math.floor((self.dimen.w - width) / 2)
    local top = self.chevron.y + math.floor((self.chevron.h - height) / 2)
    local half_width = math.floor(width / 2)
    local stroke = math.max(1, Size.line.medium)
    local drop = height - stroke
    for offset = 0, half_width - 1 do
        local y_offset = drop - math.floor(offset * drop / half_width)
        bb:paintRect(left + offset, top + y_offset, 1, stroke, Blitbuffer.COLOR_DARK_GRAY)
        bb:paintRect(left + width - offset - 1, top + y_offset, 1, stroke, Blitbuffer.COLOR_DARK_GRAY)
    end
end

function BottomNavigation:selectNeighbor(offset)
    local entry = self.neighbor_images[offset]
    if self.model.ready and entry and entry.page == self.model.page + offset then
        self.model:setPage(entry.page, true)
    end
end

function BottomNavigation:selectAt(x, immediate)
    if immediate then
        -- Snap taps and released drags to the nearest saved circle, preserving
        -- its exact page instead of rounding a book-wide slider coordinate.
        local closest, distance = nil, Screen:scaleBySize(10)
        for _, page in ipairs(self.saved_pages) do
            local delta = math.abs(x - self:sliderPageX(page))
            if delta <= distance then closest, distance = page, delta end
        end
        if closest then self.model:setPage(closest, true); return end
    end
    self.model:setRatio((x - self.slider.x) / self.slider.w, immediate)
end

function BottomNavigation:onTapPlainNavigation(_, ges)
    local pos = ges.pos
    if pos:intersectWith(self.chevron) then self.plugin:showFullConfigMenu()
    elseif pos:intersectWith(self.slider) then self:selectAt(pos.x, true)
    elseif pos:intersectWith(self.close_button) then self.plugin:closeBottomNavigation()
    elseif pos:intersectWith(self.bookmarks_button) then self.plugin:showBookmarks()
    elseif pos:intersectWith(self.toc_button) then self.plugin:showTableOfContents()
    elseif pos:intersectWith(self.search_button) then self.plugin:showFulltextSearch()
    elseif pos:intersectWith(self.previous_chapter_button) then
        local page = self:chapterDestination(-1)
        if page then self.model:setPage(page, true) end
    elseif pos:intersectWith(self.next_chapter_button) then
        local page = self:chapterDestination(1)
        if page then self.model:setPage(page, true) end
    elseif pos:intersectWith(self.neighbor_visible_rects[-1]) then self:selectNeighbor(-1)
    elseif pos:intersectWith(self.neighbor_visible_rects[1]) then self:selectNeighbor(1)
    elseif pos:intersectWith(self.origin_row) then self.model:setPage(self.model.origin, true)
    elseif pos:intersectWith(self.preview_image_rect) then
        if self.model.ready then self.plugin:commitNavigationPreview(self.model.page) end
    end
    return true
end

function BottomNavigation:onPanPlainNavigation(_, ges)
    if not self.slider_dragging and ges.start_pos and ges.start_pos:intersectWith(self.slider) then
        self.slider_dragging = true
    end
    if self.slider_dragging then self:selectAt(ges.pos.x, false) end
    return true
end
BottomNavigation.onHoldPanPlainNavigation = BottomNavigation.onPanPlainNavigation

function BottomNavigation:onReleasePlainNavigation(_, ges)
    if self.slider_dragging then
        self.slider_dragging = false
        self:selectAt(ges.pos.x, true)
    end
    return true
end
BottomNavigation.onHoldReleasePlainNavigation = BottomNavigation.onReleasePlainNavigation

function BottomNavigation:onSwipePlainNavigation(_, ges)
    if self.slider_dragging or ges.pos:intersectWith(self.slider) then
        self.slider_dragging = false
        local x = ges.pos.x
        if ges.direction == "east" then x = x + (ges.distance or 0)
        elseif ges.direction == "west" then x = x - (ges.distance or 0) end
        self:selectAt(x, true)
    elseif ges.direction == "north" and ges.pos:intersectWith(self.chevron) then
        self.plugin:showFullConfigMenu()
    elseif ges.pos:intersectWith(self.carousel_rect) then
        if ges.direction == "west" then self.model:setPage(self.model.page + 1, true)
        elseif ges.direction == "east" then self.model:setPage(self.model.page - 1, true) end
    end
    return true
end

function BottomNavigation:onIgnorePlainNavigation() return true end
BottomNavigation.onDoubleTapPlainNavigation = BottomNavigation.onIgnorePlainNavigation
BottomNavigation.onIgnoreMultiswipePlainNavigation = BottomNavigation.onIgnorePlainNavigation

function BottomNavigation:onShow()
    UIManager:setDirty(self, "ui", self.dimen)
    self.model:request()
end

function BottomNavigation:onCloseWidget()
    self.model:close()
    self:clearImage()
    self:clearNeighborImages()
    for _, icon in pairs(self.icons) do icon:free() end
    self.icons = {}
    for _, widget in pairs(self.labels) do widget:free() end
    self.labels = {}
    if self.plugin.bottom_navigation == self then self.plugin.bottom_navigation = nil end
    UIManager:setDirty(nil, "flashui", self.dimen)
end

return BottomNavigation
