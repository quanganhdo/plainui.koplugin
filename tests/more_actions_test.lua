package.path = "./?.lua;./?/init.lua;" .. package.path
local H = require("tests.test_helper")
local test, run = H.newSuite()
local equal, truthy = H.assertEqual, H.assertTruthy
local touch = true
local device = { isTouchDevice = function() return touch end }
package.loaded["device"] = device
package.loaded["gettext"] = function(t) return t end
local Actions = require("modules.reader.more_actions")
local function fixture()
    return {
        bookinfo = {onShowBookInfo = function() end, onShowBookCover = function() end},
        dictionary = {onShowDictionaryLookup = function() end},
        kosync = {settings = {username = "configured", userkey = "configured"},
            onKOSyncPushProgress = function() end, onKOSyncPullProgress = function() end},
        statistics = {canSync = function(_, skip_server_check)
            equal(skip_server_check, nil, "Must check the configured statistics destination")
            return true
        end, onSyncBookStats = function() end},
    }
end
local function find(items, key)
    for _, item in ipairs(items) do if item.key == key then return item end end
end

test("reader menu groups native book, configured sync and touch actions", function()
    local items = Actions.getItems(fixture())
    local expected = {"book_info", "cover", "dictionary", "upload_progress", "download_progress", "sync_stats", "disable_touch"}
    equal(#items, #expected)
    for i, key in ipairs(expected) do
        equal(items[i].key, key)
        equal(items[i].separator, (i == 3 or i == 6) and true or nil)
    end
    equal(items[4].event, "KOSyncPushProgress")
    equal(items[5].event, "KOSyncPullProgress")
    equal(items[6].event, "SyncBookStats")
    equal(items[7].arg, true)
end)

test("sync actions stay hidden without complete native configuration", function()
    local ui = fixture()
    for _, missing in ipairs{ "username", "userkey" } do
        for _, value in ipairs{ false, "", " " } do
            ui = fixture()
            ui.kosync.settings[missing] = value
            local items = Actions.getItems(ui)
            equal(find(items, "upload_progress"), nil)
            equal(find(items, "download_progress"), nil)
        end
        ui = fixture(); ui.kosync.settings[missing] = nil
        equal(find(Actions.getItems(ui), "upload_progress"), nil)
    end
    ui = fixture(); ui.statistics.canSync = function() return false end
    equal(find(Actions.getItems(ui), "sync_stats"), nil)
    ui.kosync.settings = nil
    local items = Actions.getItems(ui)
    equal(#items, 4)
    equal(items[3].separator, true)
    equal(items[4].separator, nil)
end)

test("native sandbox wrappers remain available for configured sync actions", function()
    local ui = fixture()
    local function wrap(handler)
        return setmetatable({}, {__call = function(_, ...) return handler(...) end})
    end
    ui.kosync.onKOSyncPushProgress = wrap(ui.kosync.onKOSyncPushProgress)
    ui.kosync.onKOSyncPullProgress = wrap(ui.kosync.onKOSyncPullProgress)
    ui.statistics.onSyncBookStats = wrap(ui.statistics.onSyncBookStats)
    local items = Actions.getItems(ui)
    truthy(find(items, "upload_progress"))
    truthy(find(items, "download_progress"))
    truthy(find(items, "sync_stats"))
    ui.kosync.onKOSyncPushProgress = {}
    equal(find(Actions.getItems(ui), "upload_progress"), nil)
    ui.kosync.settings.userkey = nil
    equal(find(Actions.getItems(ui), "download_progress"), nil)
    ui.statistics.canSync = function() return false end
    equal(find(Actions.getItems(ui), "sync_stats"), nil)
end)

test("missing plugins and unsupported actions leave no empty groups", function()
    touch = false
    local ui = fixture()
    ui.kosync, ui.statistics, ui.dictionary = nil, nil, nil
    ui.bookinfo.onShowBookCover = nil
    local items = Actions.getItems(ui)
    equal(#items, 1); equal(items[1].key, "book_info"); equal(items[1].separator, nil)
    equal(#Actions.getItems({}), 0)
    touch = true
end)

test("selection closes reader overlays before invoking native actions and rechecks sync", function()
    local closed, events, shown = {}, {}, nil
    package.loaded["logger"] = {info = function() end}
    package.loaded["ui/event"] = {new = function(_, name, arg) return {name = name, arg = arg} end}
    package.loaded["ui/uimanager"] = {
        close = function(_, widget) closed[#closed + 1] = widget end,
        show = function(_, widget) shown = widget end,
    }
    package.loaded["ui/widget/confirmbox"] = {new = function(_, args) return args end}
    local Controller = require("modules.reader.controller")
    local ui = fixture()
    local c = Controller.new({path = "."}, ui)
    ui.handleEvent = function(_, event)
        equal(c.more_menu, nil); equal(c.overlay, nil)
        events[#events + 1] = event
    end
    for _, item in ipairs(Actions.getItems(ui)) do
        local menu, overlay = {}, {}
        c.more_menu, c.overlay = menu, overlay
        local count = #events
        truthy(c:runMoreAction(item.key))
        equal(closed[#closed - 1], menu); equal(closed[#closed], overlay)
        if item.key == "disable_touch" then
            equal(#events, count, "Touch must remain enabled until confirmation")
            equal(shown.ok_text, "Disable")
            shown.ok_callback()
        end
        equal(events[#events].name, item.event); equal(events[#events].arg, item.arg)
    end
    c.more_menu, c.overlay = {}, {}
    ui.kosync.settings.userkey = nil
    local count = #events
    equal(c:runMoreAction("upload_progress"), false)
    equal(c.more_menu, nil); truthy(c.overlay); equal(#events, count)
end)

test("touch instructions suggest page swipes unless physical page-turn keys are known", function()
    device.input = {event_map = { [1] = "Power" }}
    H.assertContains(Actions.getTouchInstructions(), "your e-reader")
    H.assertContains(Actions.getTouchInstructions(), "Swipes always active")
    device.input.event_map[2] = "RPgFwd"
    equal(Actions.getTouchInstructions():find("Swipes always active", 1, true), nil)
    device.input = nil
    H.assertContains(Actions.getTouchInstructions(), "Swipes always active")
    H.assertContains(Actions.getTouchInstructions(), "your e-reader")
end)

run()
