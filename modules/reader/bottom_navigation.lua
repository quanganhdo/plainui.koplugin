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
local TextWidget = require("ui/widget/textwidget")
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
    self.bar = Geom:new{ x = 0, y = h - scale(112), w = w, h = scale(112) }
    self.slider = Geom:new{ x = self.padding, y = self.bar.y + scale(36),
        w = w - 2 * self.padding, h = scale(40) }
    self.chevron = Geom:new{ x = 0, y = self.slider.y + self.slider.h,
        w = w, h = h - self.slider.y - self.slider.h }
    -- A single full-page thumbnail keeps the book's existing typography.
    local available_h = self.bar.y - 2 * scale(16)
    local preview_w = math.min(math.floor(w * 0.78), math.floor(available_h * w / h))
    local preview_h = math.floor(preview_w * h / w)
    self.preview_rect = Geom:new{ x = math.floor((w - preview_w) / 2),
        y = math.floor((self.bar.y - preview_h) / 2), w = preview_w, h = preview_h }
    self.labels = {}
    self.model = Preview.new{
        page = self.plugin.ui:getCurrentPage(),
        count = self.plugin.ui.document:getPageCount(),
        thumbnail = self.plugin.ui.thumbnail, manager = UIManager,
        width = preview_w, height = preview_h,
        changed = function()
            local had_image = self.image ~= nil
            self:clearImage()
            self.failed = false
            UIManager:setDirty(self, "ui", had_image and self.dimen or self.bar)
        end,
        rendered = function(tile)
            self:clearImage()
            if tile then
                self.image = ImageWidget:new{
                    image = tile.bb:copy(), image_disposable = true,
                    original_in_nightmode = false,
                }
            end
            self.failed = tile == nil
            UIManager:setDirty(self, "ui", self.preview_rect)
        end,
    }
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

function BottomNavigation:clearImage()
    if self.image then self.image:free(); self.image = nil end
end

function BottomNavigation:pageLabel(page)
    local ui = self.plugin.ui
    if ui.pagemap and ui.pagemap:wantsPageLabels() then
        local label = ui.pagemap:getXPointerPageLabel(ui.document:getPageXPointer(page))
        if label then return T(_("Page %1"), label) end
    end
    return T(_("Page %1"), page)
end

function BottomNavigation:drawText(bb, id, text, x, y, width, align, bold)
    local widget = self.labels[id]
    if not widget or widget.text ~= text then
        if widget then widget:free() end
        widget = TextWidget:new{
            text = text, face = Font:getFace("smallinfofont", 16),
            max_width = width, bold = bold,
        }
        self.labels[id] = widget
    end
    local size = widget:getSize()
    if align == "center" then x = x + math.floor((width - size.w) / 2)
    elseif align == "right" then x = x + width - size.w end
    widget:paintTo(bb, x, y)
end

function BottomNavigation:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local r = self.preview_rect
    bb:paintBorder(r.x, r.y, r.w, r.h, Screen:scaleBySize(1), Blitbuffer.COLOR_DARK_GRAY)
    if self.image then
        local size = self.image:getSize()
        self.image:paintTo(bb, r.x + math.floor((r.w - size.w) / 2), r.y + math.floor((r.h - size.h) / 2))
    else
        self:drawText(bb, "loading", self.failed and _("Preview unavailable") or _("Loading…"),
            r.x, r.y + math.floor(r.h / 2), r.w, "center")
    end
    local third = math.floor((self.dimen.w - 2 * self.padding) / 3)
    local label_y = self.bar.y + Screen:scaleBySize(8)
    self:drawText(bb, "origin", self.model.page ~= self.model.origin
        and "← " .. self:pageLabel(self.model.origin) or "",
        self.padding, label_y, third, "left", true)
    self:drawText(bb, "page", self:pageLabel(self.model.page),
        self.padding + third, label_y, third, "center")
    self:drawText(bb, "percent", string.format("%d%%", math.floor(self.model.page * 100 / self.model.count)),
        self.padding + 2 * third, label_y, third, "right")
    local cy = self.slider.y + math.floor(self.slider.h / 2)
    local line = math.max(1, Screen:scaleBySize(2))
    bb:paintRect(self.slider.x, cy, self.slider.w, line, Blitbuffer.COLOR_DARK_GRAY)
    local cx = self.slider.x + math.floor(self.model:ratio() * self.slider.w)
    local radius = Screen:scaleBySize(9)
    for dy = -radius, radius do
        local half = math.floor(math.sqrt(radius * radius - dy * dy))
        bb:paintRect(cx - half, cy + dy, 2 * half + 1, 1, Blitbuffer.COLOR_BLACK)
    end
    local inner = radius - line
    for dy = -inner, inner do
        local half = math.floor(math.sqrt(inner * inner - dy * dy))
        bb:paintRect(cx - half, cy + dy, 2 * half + 1, 1, Blitbuffer.COLOR_WHITE)
    end
    local center = math.floor(self.dimen.w / 2)
    local top = self.chevron.y + math.floor(self.chevron.h / 2) - Screen:scaleBySize(4)
    for dy = 0, Screen:scaleBySize(7) do
        bb:paintRect(center - dy, top + dy, line, line, Blitbuffer.COLOR_DARK_GRAY)
        bb:paintRect(center + dy, top + dy, line, line, Blitbuffer.COLOR_DARK_GRAY)
    end
end

function BottomNavigation:selectAt(x, immediate)
    self.model:setRatio((x - self.slider.x) / self.slider.w, immediate)
end

function BottomNavigation:onTapPlainNavigation(_, ges)
    local pos = ges.pos
    if pos:intersectWith(self.chevron) then self.plugin:showFullConfigMenu()
    elseif pos:intersectWith(self.slider) then self:selectAt(pos.x, true)
    elseif pos:intersectWith(self.preview_rect) then
        if self.model.ready then self.plugin:commitNavigationPreview(self.model.page) end
    elseif pos.y >= self.bar.y then
        if pos.x < self.padding + (self.dimen.w - 2 * self.padding) / 3 then
            self.model:setPage(self.model.origin, true)
        end
    else self.plugin:closeBottomNavigation() end
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
    elseif ges.direction == "south" then self.plugin:closeBottomNavigation()
    elseif ges.pos:intersectWith(self.preview_rect) then
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
    for _, widget in pairs(self.labels) do widget:free() end
    self.labels = {}
    if self.plugin.bottom_navigation == self then self.plugin.bottom_navigation = nil end
    UIManager:setDirty(nil, "flashui", self.dimen)
end

return BottomNavigation
