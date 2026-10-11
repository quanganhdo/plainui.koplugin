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
package.loaded["ffi/util"] = {template = function(t, ...)
    for i, v in ipairs{...} do t = t:gsub("%%" .. i, tostring(v)) end
    return t
end}
package.loaded["gettext"] = function(t) return t end
package.loaded["ui/widget/textwidget"] = {new = function(_, t)
    function t:getSize() return {w = math.min(self.max_width, #self.text * 6), h = 16} end
    function t:paintTo() end
    function t:free() end
    return t
end}
package.loaded["ui/widget/imagewidget"] = {new = function(_, t)
    function t:getSize() return {w = self.image.w, h = self.image.h} end
    function t:paintTo(bb, x, y) bb.calls[#bb.calls + 1] = {kind = "image", x = x, y = y, w = self.image.w, h = self.image.h} end
    function t:free() self.freed = true end
    return t
end}
package.loaded["ui/uimanager"] = {
    setDirty = function() end, scheduleIn = function() end, unschedule = function() end,
}
local Widget = require("modules.reader.bottom_navigation")
local function fixture()
    local requested, chapter_from = {}, {}
    local ui = {
        getCurrentPage = function() return 25 end,
        document = {getPageCount = function() return 100 end, getProps = function() return {title = "Book"} end},
        toc = {
            getPreviousChapter = function(_, page) chapter_from.previous = page; return page > 10 and 10 or nil end,
            getNextChapter = function(_, page) chapter_from.next = page; return page < 90 and 90 or nil end,
            getTocTitleByPage = function(_, page) return page < 90 and "Chapter One" or "Chapter Two" end,
        },
        thumbnail = {
            getPageThumbnail = function(_, page, w, h, _, callback)
                requested[#requested + 1] = page
                local factor = math.min(w / 600, h / 800)
                callback({bb = {copy = function() return {w = math.floor(600 * factor), h = math.floor(800 * factor)} end}})
            end,
            cancelPageThumbnailRequests = function() end,
        },
    }
    local plugin = {ui = ui, closeBottomNavigation = function(self) self.closed = true end,
        commitNavigationPreview = function(self, page) self.committed = page end}
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
    return widget, bb, plugin, requested, chapter_from, tap
end

test("preview image fits inside four-sided border and backdrop is captured once", function()
    local w, bb = fixture()
    w:onShow()
    w:paintTo(bb, 0, 0)
    local image, border, image_index, border_index
    for i, call in ipairs(bb.calls) do
        if call.kind == "image" then image, image_index = call, i
        elseif call.kind == "border" and call.w == w.preview_rect.w then border, border_index = call, i end
    end
    truthy(image and border)
    truthy(border_index > image_index, "Image must not overwrite page border")
    truthy(image.x > border.x and image.y > border.y)
    truthy(image.x + image.w < border.x + border.w and image.y + image.h < border.y + border.h)
    w:paintTo(bb, 0, 0)
    equal(bb.copies, 1)
    local background = w.background
    w:onCloseWidget()
    equal(background.freed, true)
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

test("page controls and close control cannot accidentally commit the preview", function()
    local w, _, plugin, _, _, tap = fixture()
    w:onShow()
    tap(w.next_page_button)
    equal(w.model.page, 26)
    equal(plugin.committed, nil)
    tap(w.previous_page_button)
    equal(w.model.page, 25)
    tap(w.close_button)
    equal(plugin.closed, true)
    equal(plugin.committed, nil)
    w:onCloseWidget()
end)

run()
