package.path = package.path .. ";./?.lua;./?/init.lua"
local Helper = require("tests.test_helper")
local test, run = Helper.newSuite()
local equal, truthy = Helper.assertEqual, Helper.assertTruthy

local pending, closed, shown = {}, {}, {}
local manager = { _window_stack = {} }
function manager:nextTick(callback) pending[#pending + 1] = callback end
function manager:unschedule(callback)
    for i = #pending, 1, -1 do
        if pending[i] == callback then table.remove(pending, i) end
    end
end
function manager:show(widget)
    self._window_stack[#self._window_stack + 1] = { widget = widget }
    shown[#shown + 1] = widget
end
function manager:close(widget)
    closed[#closed + 1] = widget
    for i = #self._window_stack, 1, -1 do
        if self._window_stack[i].widget == widget then table.remove(self._window_stack, i) end
    end
end
function manager:setDirty() end
package.loaded["ui/uimanager"] = manager
package.loaded["modules.reader.return_footer"] = { new = function(_, options)
    return { history = options.history, dimen = { y = 100 } }
end }
local History = require("modules.reader.navigation_history")
local function tick()
    while #pending > 0 do table.remove(pending, 1)() end
end
local function location(page) return { xpointer = tostring(page) } end
local function fixture()
    pending, closed, shown = {}, {}, {}
    local ui = { current = "10", document = {
        getPageFromXPointer = function(_, xp) return tonumber(xp) end,
    } }
    local link = { location_stack = {}, forward_location_stack = {} }
    function link:compareLocationToCurrent(saved) return saved.xpointer == ui.current end
    function link:onClearForwardLocationStack() self.forward_location_stack = {} end
    function link:addCurrentLocationToStack()
        self:onClearForwardLocationStack()
        self.location_stack[#self.location_stack + 1] = location(ui.current)
    end
    function link:onClearLocationStack()
        self.location_stack = {}
        self:onClearForwardLocationStack()
    end
    function link:popFromLocationStack() return table.remove(self.location_stack) end
    function link:onGoBackLink() ui.back_calls = (ui.back_calls or 0) + 1; return true end
    function link:onGoForwardLink() ui.forward_calls = (ui.forward_calls or 0) + 1; return true end
    ui.link = link
    manager._window_stack = { { widget = ui } }
    local history = History.new(ui)
    history:install()
    return ui, history
end

test("destinations skip the current entry without changing history", function()
    local ui, history = fixture()
    ui.current = "30"
    ui.link.location_stack = { location(10), location(20) }
    ui.link.forward_location_stack = { location(50), location(40), location(30) }
    local back, forward = history:getDestinations()
    equal(back.xpointer, "20")
    equal(forward.xpointer, "40")
    equal(#ui.link.location_stack, 2)
    equal(#ui.link.forward_location_stack, 3)
    ui.current = "20"
    back = history:getDestinations()
    equal(back.xpointer, "10")
    -- Match KOReader's single-entry skip even if a trail contains duplicates.
    ui.link.location_stack = { location(20), location(20) }
    back = history:getDestinations()
    equal(back, ui.link.location_stack[1])
    history:stop()
end)

test("push waits for navigation and opens one footer", function()
    local ui, history = fixture()
    ui.link:addCurrentLocationToStack()
    equal(history.footer, nil)
    ui.current = "20"
    tick()
    truthy(history.footer)
    equal(#shown, 1)
    history:install()
    ui.link:addCurrentLocationToStack()
    ui.current = "30"
    tick()
    equal(#shown, 1)
    equal(#ui.link.location_stack, 2)
    history:stop()
end)

test("menus hide the footer and closing restores it", function()
    local ui, history = fixture()
    ui.link:addCurrentLocationToStack(); ui.current = "20"; tick()
    local dialog = {}
    manager:show(dialog)
    equal(history.footer, nil)
    tick()
    equal(history.footer, nil)
    manager:close(dialog); tick()
    truthy(history.footer)
    local toast = { toast = true }
    local footer = history.footer
    manager:show(toast); tick()
    equal(history.footer, footer)
    manager:close(toast); tick()
    history:onSetDimensions(); tick()
    truthy(history.footer ~= footer)
    history:stop()
end)

test("Stay here preserves the trail and page turns do not reopen it", function()
    local ui, history = fixture()
    ui.link:addCurrentLocationToStack(); ui.current = "20"; tick()
    ui.link.forward_location_stack = { location(40), location(20) }
    local back, forward = ui.link.location_stack, ui.link.forward_location_stack
    history:stayHere()
    equal(history.footer, nil)
    equal(ui.link.location_stack, back)
    equal(ui.link.forward_location_stack, forward)
    ui.current = "21"; history:queueRefresh(); tick()
    equal(history.footer, nil)
    -- A new branch uses the native push and clears native forward history.
    ui.link:addCurrentLocationToStack(); ui.current = "50"; tick()
    truthy(history.footer)
    equal(#ui.link.forward_location_stack, 0)
    equal(ui.link.location_stack[2].xpointer, "21")
    history:stop()
end)

test("Back and Forward delegate to native navigation and reactivate the footer", function()
    local ui, history = fixture()
    ui.link.location_stack = { location(5) }
    history:goBack(); tick()
    equal(ui.back_calls, 1)
    truthy(history.footer)
    history:stayHere()
    history:goForward(); tick()
    equal(ui.forward_calls, 1)
    truthy(history.footer)
    ui.link:onClearLocationStack(); tick()
    equal(history.footer, nil)
    history:stop()
end)

test("labels prefer enabled printed pages and fall back to rendered pages", function()
    local ui, history = fixture()
    equal(history:getPageLabel(location(105)), "105")
    ui.pagemap = {
        wantsPageLabels = function() return true end,
        getXPointerPageLabel = function(_, xp) return xp == "105" and "Page vii" or nil end,
        cleanPageLabel = function(_, label) return label:gsub("Page ", "") end,
    }
    equal(history:getPageLabel(location(105)), "vii")
    equal(history:getPageLabel(location(106)), "106")
    ui.pagemap.wantsPageLabels = function() return false end
    equal(history:getPageLabel(location(105)), "105")
    equal(history:getPageLabel({ { page = 12 } }), "12")
    equal(history:getPageLabel(nil), nil)
    history:stop()
end)

test("stop cancels deferred work and restores hooks without undoing later hooks", function()
    local original_show = manager.show
    local ui, history = fixture()
    local later = function() end
    ui.link.onGoForwardLink = later
    ui.link:addCurrentLocationToStack(); ui.current = "20"
    history:stop(); tick()
    equal(history.footer, nil)
    equal(ui.link.onGoForwardLink, later)
    equal(manager.show, original_show)
    equal(#pending, 0)
    -- Inherited methods should be restored by removing the instance override.
    ui, history = fixture()
    history:stop()
    local inherited = { method = function() return true end }
    local instance = setmetatable({}, { __index = inherited })
    history = History.new(ui)
    history:hook(instance, "method", function() end)
    equal(instance:method(), true)
    history:stop()
    equal(rawget(instance, "method"), nil)
end)

run()
