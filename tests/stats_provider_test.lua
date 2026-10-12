package.path = "./?.lua;./?/init.lua;" .. package.path
local H = require("tests.test_helper")
local test, run = H.newSuite()
local equal, truthy = H.assertEqual, H.assertTruthy
local Provider = require("modules.reader.stats_provider")

test("enabled Reading Insights takes priority over a standalone patch", function()
    local plugin = {onShowReadingStatsPopup = function() end}
    local ui = {readinginsights = plugin, onShowReadingStatsPopup = function() end}
    equal(Provider.findExternal(ui), plugin)
    ui.readinginsights = nil
    equal(Provider.findExternal(ui), ui)
end)

test("derivative plugins can use another name and native sandbox handlers", function()
    local plugin = {onShowReadingStatsPopup = setmetatable({}, {__call = function() end})}
    equal(Provider.findExternal{plugin}, plugin)
    equal(Provider.findExternal{readinginsights = {onShowReadingStatsPopup = {}}}, nil)
end)

test("all-time Insights and KoInsight sync do not replace book progress", function()
    equal(Provider.findExternal{
        {onShowReadingInsightsPopup = function() end},
        {onKoInsightSync = function() end},
        plainui_reading_stats_popup = true,
        onShowPlainUIBookOverview = function() end,
    }, nil)
    equal(Provider.findExternal(nil), nil)
end)

test("external popup opens without toolbar or Plain UI layout arguments", function()
    package.loaded["ui/event"] = {}
    package.loaded["logger"] = {}
    package.loaded["ui/uimanager"] = {close = function() end}
    package.loaded["modules.reader.reading_stats_popup"] = {canShow = function() return true end,
        show = function() error("External provider should open its own popup") end}
    local Controller = require("modules.reader.controller")
    local c, calls = nil, 0
    local plugin = {onShowReadingStatsPopup = function(self, ...)
        equal(self, c.ui.readinginsights)
        equal(select("#", ...), 0)
        equal(c.overlay, nil)
        equal(c.typography_overlay, nil)
        equal(c.bottom_navigation, nil)
        equal(c.stats_popup, nil)
        calls = calls + 1
        return true
    end}
    c = Controller.new({path = "/plugin"}, {readinginsights = plugin})
    c.overlay, c.typography_overlay, c.bottom_navigation = {}, {}, {}
    c.closeTypographyOverlay = function(self) self.typography_overlay = nil end
    c.closeBottomNavigation = function(self) self.bottom_navigation = nil end
    equal(c:hasReadingStatsPopup(), true)
    equal(c:showReadingStatsPopup(140), true)
    equal(calls, 1)
end)

test("unversioned standalone patches remain selectable after toolbar reopen", function()
    local calls = 0
    local ui = {onShowReadingStatsPopup = function() calls = calls + 1;return true end}
    local Controller = require("modules.reader.controller")
    local c = Controller.new({path = "/plugin"}, ui)
    c.overlay = {}
    truthy(c:showReadingStatsPopup(140))
    c.overlay = {}
    truthy(c:showReadingStatsPopup(140))
    equal(calls, 2)
end)

run()
