package.path = "./?.lua;./?/init.lua;" .. package.path
local H = require("tests.test_helper")
local test, run = H.newSuite()
local equal, truthy = H.assertEqual, H.assertTruthy
local Geom = {}
function Geom:new(t)
    function t:intersectWith(r)
        return self.x >= r.x and self.x <= r.x + r.w and self.y >= r.y and self.y <= r.y + r.h
    end
    function t:notIntersectWith(r) return not self:intersectWith(r) end
    return t
end
local Container = {}
function Container:extend(t)
    t.__index = t
    function t:new(options) setmetatable(options, self); options:init(); return options end
    return t
end
package.loaded["ui/widget/container/inputcontainer"] = Container
package.loaded["ui/geometry"] = Geom
package.loaded["ui/gesturerange"] = {new = function(_, t) return t end}
package.loaded["device"] = {screen = {
    scaleBySize = function(_, n) return n end,
    getWidth = function() return 600 end, getHeight = function() return 800 end,
}}
package.loaded["ffi/blitbuffer"] = {COLOR_WHITE = 0, COLOR_BLACK = 1, COLOR_DARK_GRAY = 2}
package.loaded["ui/font"] = {getFace = function() return {} end}
package.loaded["ui/size"] = {line = {medium = 2, thick = 3}, item = {height_big = 40}, padding = {large = 10}}
package.loaded["ffi/util"] = {template = function(t, ...)
    for i, v in ipairs{...} do t = t:gsub("%%" .. i, tostring(v)) end
    return t
end}
package.loaded["gettext"] = function(t) return t end
package.loaded["ui/widget/textwidget"] = {new = function(_, t)
    function t:getSize() return {w = math.min(self.max_width, #self.text * 6), h = 16} end
    function t:paintTo(_, x, y) self.x, self.y = x, y end
    function t:free() end
    return t
end}
package.loaded["ui/widget/imagewidget"] = {new = function(_, t)
    function t:getSize() return self.file and {w = self.width, h = self.height} or {w = self.image.w, h = self.image.h} end
    function t:paintTo(bb, x, y)
        local size = self:getSize()
        bb.calls[#bb.calls + 1] = {kind = self.file and "icon" or "image", x = x, y = y, w = size.w, h = size.h}
    end
    function t:free() self.freed = true end
    return t
end}
package.loaded["ui/uimanager"] = {
    setDirty = function() end, scheduleIn = function() end, unschedule = function() end,
}
local Widget = require("modules.reader.bottom_navigation")
local function fixture(deferred, link)
    local requested, chapter_from, pending, bookmarks = {}, {}, {}, {}
    local ui = {
        link = link,
        getCurrentPage = function() return 25 end,
        document = {getPageCount = function() return 100 end, getProps = function() return {title = "Book"} end,
            getPageXPointer = function(_, page) return tostring(page) end,
            getPageFromXPointer = function(_, xp) return tonumber(xp) end},
        bookmark = {isPageBookmarked = function(_, xp) return bookmarks[tonumber(xp)] == true end},
        toc = {
            getPreviousChapter = function(_, page) chapter_from.previous = page; return page > 10 and 10 or nil end,
            getNextChapter = function(_, page) chapter_from.next = page; return page < 90 and 90 or nil end,
            getTocTitleByPage = function(_, page) return page < 90 and "Chapter One" or "Chapter Two" end,
        },
        thumbnail = {
            getPageThumbnail = function(_, page, w, h, _, callback)
                requested[#requested + 1] = page
                local factor = math.min(w / 600, h / 800)
                local tile = {bb = {copy = function() return {w = math.floor(600 * factor), h = math.floor(800 * factor)} end}}
                if deferred then pending[#pending + 1] = function() callback(tile) end
                else callback(tile) end
            end,
            cancelPageThumbnailRequests = function() end,
        },
    }
    local plugin = {ui = ui, path = ".", closeBottomNavigation = function(self) self.closed = true end,
        commitNavigationPreview = function(self, page) self.committed = page end,
        showGotoDialog = function(self) self.goto_opened = true end,
        togglePreviewBookmark = function(self, page)
            self.bookmarked_page = page
            bookmarks[page] = not bookmarks[page]
        end,
        showBookmarks = function(self) self.bookmarks_opened = true end,
        showTableOfContents = function(self) self.toc_opened = true end,
        showFulltextSearch = function(self) self.search_opened = true end}
    local widget = Widget:new{plugin = plugin}
    local bb = {calls = {}}
    function bb:copy()
        self.copies = (self.copies or 0) + 1
        return {lightenRect = function() end, free = function(t) t.freed = true end}
    end
    function bb:blitFrom() end
    function bb:paintRect() end
    function bb:paintBorder(x, y, w, h) self.calls[#self.calls + 1] = {kind = "border", x = x, y = y, w = w, h = h} end
    local function tap(r)
        widget:onTapPlainNavigation(nil, {pos = Geom:new{x = r.x + r.w / 2, y = r.y + r.h / 2}})
    end
    return widget, bb, plugin, requested, chapter_from, tap, pending
end

test("fixed-page previews use numeric bookmarks and page labels without text locations", function()
    local w, bb, plugin, _, _, tap = fixture()
    local ui = plugin.ui
    ui.paging = {}
    ui.toc = nil
    ui.document.getPageXPointer = function() error("Fixed pages have no text locations") end
    ui.pagemap = { wantsPageLabels = function() return true end,
        getXPointerPageLabel = function() error("Fixed pages have no text page map") end }
    equal(w:pageLabel(25), "Page 25")
    equal(w:chapterTitle(), "Page 25")
    equal(w:chapterDestination(-1), nil)
    equal(w:chapterDestination(1), nil)
    w:onShow()
    equal(w:isPreviewBookmarked(), false)
    tap(w.preview_bookmark_button)
    equal(plugin.bookmarked_page, 25)
    equal(w:isPreviewBookmarked(), true)
    w.model:setPage(70, true)
    equal(w:chapterTitle(), "Page 70")
    equal(w:isPreviewBookmarked(), false)
    w:paintTo(bb, 0, 0)
    tap(w.chapter_button)
    equal(plugin.goto_opened, true)
    equal(plugin.committed, nil)
    w:onCloseWidget()
end)

test("the saved circle marks only the opening page regardless of navigation history", function()
    local back = {{xpointer = "5"}, {xpointer = "10"}, {xpointer = "90"}, {xpointer = "90"}, {xpointer = "26"}, {xpointer = "25"}}
    local w, _, plugin = fixture(false, {location_stack = back})
    equal(#w.saved_pages, 1)
    equal(w.saved_pages[1], 25)
    w.model:setPage(70, true)
    equal(#w.saved_pages, 1)
    equal(w.saved_pages[1], 25)
    equal(#back, 6)
    equal(plugin.committed, nil)
    local other = fixture(false, {location_stack = {{xpointer = "0"}, {xpointer = "101"}},
        forward_location_stack = {{{page = 100}}, {xpointer = "1"}, {xpointer = "25"}}})
    equal(#other.saved_pages, 1)
    equal(other.saved_pages[1], 25)
end)

test("taps and released drags snap to the opening circle but not navigation history", function()
    local w, _, plugin = fixture(false, {location_stack = {{xpointer = "90"}}})
    w:onShow()
    w.model:setPage(70, true)
    local y = w.slider.y + w.slider.h / 2
    local function tapX(x)
        w:onTapPlainNavigation(nil, {pos = Geom:new{x = x, y = y}})
    end
    tapX(w:sliderPageX(25) + 4)
    equal(w.model.page, 25)
    tapX(w:sliderPageX(90) - 4)
    equal(w.model.page, 89)
    local x = w:sliderPageX(25) + 4
    w:onPanPlainNavigation(nil, {start_pos = Geom:new{x = w:sliderPageX(90), y = y}, pos = Geom:new{x = x, y = y}})
    truthy(w.model.page ~= 25, "Continuous dragging must remain free")
    w:onReleasePlainNavigation(nil, {pos = Geom:new{x = x, y = y}})
    equal(w.model.page, 25)
    tapX(w:sliderPageX(60))
    equal(w.model.page, 60)
    equal(w.model.origin, 25)
    equal(plugin.committed, nil)
    equal(#plugin.ui.link.location_stack, 1)
    w.model.count, w.model.origin, w.model.page = 1, 1, 1
    w.saved_pages = {1}
    equal(w:sliderPageX(1), w.slider.x)
    tapX(w.slider.x)
    equal(w.model.page, 1)
    w:onCloseWidget()
end)

test("page borders appear before thumbnails and stay visible through rapid jumps", function()
    local w, bb, plugin, requested, _, tap, pending = fixture(true)
    local function borders()
        bb.calls = {}
        w:paintTo(bb, 0, 0)
        local count = 0
        for _, call in ipairs(bb.calls) do
            if call.kind == "border" and call.y == w.preview_rect.y then count = count + 1 end
        end
        return count
    end
    w:onShow()
    equal(borders(), 3)
    pending[1]()
    pending[2]()
    pending[3]()
    local center, left, right = w.image, w.neighbor_images[-1].image, w.neighbor_images[1].image
    w.model:setPage(40, false)
    w.model:setPage(50, false)
    equal(center.freed, true)
    equal(left.freed, true)
    equal(right.freed, true)
    equal(w.image, nil)
    equal(next(w.neighbor_images), nil)
    equal(borders(), 3)
    equal(w.labels.page_count.text, "Page 50 of 100")
    tap(w.preview_image_rect)
    equal(plugin.committed, nil)
    pending[2]() -- A canceled neighboring response must not refill an old card.
    equal(next(w.neighbor_images), nil)
    w.model.generate()
    equal(requested[#requested], 50)
    pending[4]()
    truthy(w.image)
    equal(next(w.neighbor_images), nil)
    equal(borders(), 3)
    pending[5]()
    pending[6]()
    truthy(w.neighbor_images[-1] and w.neighbor_images[1])
    w.model:setPage(1, false)
    equal(borders(), 2)
    w.model:setPage(100, false)
    equal(borders(), 2)
    w:onCloseWidget()
end)

test("carousel images fit inside their borders and the selected card stays centered", function()
    local w, bb = fixture()
    w:onShow()
    w:paintTo(bb, 0, 0)
    local image, border, image_index, border_index
    for i, call in ipairs(bb.calls) do
        if call.kind == "image" and call.x > 0 and call.x < w.preview_rect.x + w.preview_rect.w then image, image_index = call, i
        elseif call.kind == "border" and call.x == w.preview_rect.x then border, border_index = call, i end
    end
    truthy(image and border)
    truthy(border_index > image_index, "Image must not overwrite page border")
    truthy(image.x > border.x and image.y > border.y)
    truthy(image.x + image.w < border.x + border.w and image.y + image.h < border.y + border.h)
    equal(w.preview_rect.y, w.header.h + math.floor((w.bar.y - w.header.h - w.preview_rect.h) / 2))
    truthy(w.neighbor_rects[-1].x < 0)
    truthy(w.neighbor_rects[1].x + w.neighbor_rects[1].w > w.dimen.w)
    truthy(w.neighbor_images[-1] and w.neighbor_images[1])
    local left, right = w.neighbor_images[-1].image, w.neighbor_images[1].image
    w:onCloseWidget()
    equal(left.freed, true)
    equal(right.freed, true)
end)

test("bottom actions share toolbar sizing and open Go to page, Bookmarks, TOC or Search without a preview jump", function()
    local w, bb, plugin, _, _, tap = fixture()
    w:onShow()
    w:paintTo(bb, 0, 0)
    local style = require("modules.shared.toolbar_style")
    for _, r in ipairs{w.previous_chapter_button, w.next_chapter_button, w.bookmarks_button, w.toc_button, w.search_button} do
        equal(r.w, style.button_width)
        equal(r.h, style.button_height)
    end
    equal(w.bookmarks_button.y, w.origin_row.y)
    equal(w.toc_button.y, w.origin_row.y)
    equal(w.search_button.y, w.origin_row.y)
    truthy(w.origin_row.x + w.origin_row.w < w.toc_button.x)
    equal(w.toc_button.x + w.toc_button.w + style.button_gap, w.bookmarks_button.x)
    equal(w.bookmarks_button.x + w.bookmarks_button.w + style.button_gap, w.search_button.x)
    equal(w.labels.percent, nil)
    equal(w.icons.bookmarks.width, style.icon_size)
    equal(w.icons.toc.width, style.icon_size)
    equal(w.icons.search.height, style.icon_size)
    tap(w.chapter_button)
    equal(plugin.goto_opened, true)
    tap(w.bookmarks_button)
    equal(plugin.bookmarks_opened, true)
    tap(w.toc_button)
    equal(plugin.toc_opened, true)
    tap(w.search_button)
    equal(plugin.search_opened, true)
    equal(plugin.committed, nil)
    equal(w.model.page, w.model.origin)
    local icon = w.icons.bookmarks
    w:onCloseWidget()
    equal(icon.freed, true)
end)

test("the preview bookmark toggles the selected page without moving or committing the reader", function()
    local w, bb, plugin, _, _, tap = fixture()
    w:onShow()
    w.model:setPage(70, true)
    equal(w:isPreviewBookmarked(), false)
    tap(w.preview_bookmark_button)
    equal(plugin.bookmarked_page, 70)
    equal(w:isPreviewBookmarked(), true)
    w:paintTo(bb, 0, 0)
    tap(w.preview_bookmark_button)
    equal(w:isPreviewBookmarked(), false)
    equal(plugin.ui:getCurrentPage(), 25)
    equal(w.model.origin, 25)
    equal(w.model.page, 70)
    equal(plugin.committed, nil)
    equal(plugin.closed, nil)
    w:onCloseWidget()
    w, _, plugin, _, _, tap = fixture(true)
    w:onShow()
    tap(w.preview_bookmark_button)
    equal(plugin.bookmarked_page, nil)
    w:onCloseWidget()
end)

test("chapter buttons navigate from preview page without committing a reading jump", function()
    local w, bb, plugin, requested, from, tap = fixture()
    w:onShow()
    w.model:setPage(50, true)
    tap(w.next_chapter_button)
    equal(from.next, 50)
    equal(w.model.page, 90)
    equal(w.model.origin, 25)
    equal(plugin.committed, nil)
    w:paintTo(bb, 0, 0)
    equal(w.labels.chapter.text, "Chapter Two")
    equal(w.labels.chapter.y + w.labels.chapter:getSize().h / 2,
        w.chapter_row.y + w.chapter_row.h / 2)
    equal(w.labels.page_count.text, "Page 90 of 100")
    local count = #requested
    tap(w.next_chapter_button)
    equal(w.model.page, 90)
    equal(#requested, count)
    tap(w.previous_chapter_button)
    equal(from.previous, 90)
    equal(w.model.page, 10)
    w:onCloseWidget()
end)

test("neighbor previews center pages and close cannot commit a reading jump", function()
    local w, _, plugin, _, _, tap = fixture()
    w:onShow()
    tap(w.neighbor_visible_rects[1])
    equal(w.model.page, 26)
    equal(plugin.committed, nil)
    tap(w.neighbor_visible_rects[-1])
    equal(w.model.page, 25)
    tap(w.close_button)
    equal(plugin.closed, true)
    equal(plugin.committed, nil)
    w:onCloseWidget()
end)

test("empty taps and downward swipes are consumed without closing or committing", function()
    local w, _, plugin = fixture()
    w:onShow()
    for _, point in ipairs{
        {x = 0, y = 0},
        {x = w.dimen.w / 2, y = w.preview_rect.y / 2},
        {x = w.dimen.w / 2, y = (w.preview_rect.y + w.preview_rect.h + w.bar.y) / 2},
        {x = w.preview_rect.x + 2, y = w.preview_rect.y + 2},
    } do
        local pos = Geom:new{x = point.x, y = point.y}
        equal(w:onTapPlainNavigation(nil, {pos = pos}), true)
        equal(w:onSwipePlainNavigation(nil, {pos = pos, direction = "south"}), true)
        equal(plugin.closed, nil)
        equal(plugin.committed, nil)
        equal(w.model.page, 25)
    end
    w:onCloseWidget()
end)

test("stale or unavailable neighboring previews do not select a different page", function()
    local w, _, plugin, _, _, tap = fixture()
    w:onShow()
    w.model.ready = false
    tap(w.neighbor_visible_rects[1])
    equal(w.model.page, 25)
    w.model.ready = true
    w.neighbor_images[1].page = 99
    tap(w.neighbor_visible_rects[1])
    equal(w.model.page, 25)
    equal(plugin.committed, nil)
    w:onCloseWidget()
end)

run()
