package.path = "./?.lua;./?/init.lua;" .. package.path

local TestHelper = require("tests.test_helper")
local assertEqual = TestHelper.assertEqual
local assertTruthy = TestHelper.assertTruthy
local test, run = TestHelper.newSuite()

local function withModules(modules, fn)
    local saved_loaded = {}
    local saved_preload = {}
    for name, value in pairs(modules) do
        saved_loaded[name] = package.loaded[name]
        saved_preload[name] = package.preload[name]
        package.loaded[name] = nil
        package.preload[name] = function()
            return value
        end
    end
    local ok, err = pcall(fn)
    for name in pairs(modules) do
        package.loaded[name] = saved_loaded[name]
        package.preload[name] = saved_preload[name]
    end
    if not ok then
        error(err, 0)
    end
end

test("compatibility detects every owned legacy patch filename", function()
    local UserPatches = require("modules.compat.user_patches")
    local present = {}
    for _, filename in ipairs(UserPatches.OWNED_PATCHES) do
        present[filename] = true
    end
    local detected = UserPatches.detect{
        patches_dir = "/patches",
        file_exists = function(path)
            return present[path:match("([^/]+)$")] == true
        end,
    }
    assertEqual(#detected, #UserPatches.OWNED_PATCHES)
    for index, filename in ipairs(UserPatches.OWNED_PATCHES) do
        assertEqual(detected[index], filename)
    end
end)

test("compatibility recognizes all reading stats legacy signals", function()
    local UserPatches = require("modules.compat.user_patches")
    local signals = {
        { reading_stats_popup_patch_version = "1.1.0" },
        { reading_stats_popup_api_version = 2 },
        { onShowReadingStatsPopup = function() end },
    }
    for _, reader_ui in ipairs(signals) do
        local detected = UserPatches.detect{
            patches_dir = "/missing",
            file_exists = function() return false end,
            reader_ui = reader_ui,
        }
        assertEqual(#detected, 1)
        assertEqual(detected[1], "2-reading-stats-popup.lua")
    end
end)

test("compatibility notice is non-blocking and shown once", function()
    local UserPatches = require("modules.compat.user_patches")
    UserPatches._test.reset()
    UserPatches.initialize{
        patches_dir = "/patches",
        file_exists = function() return true end,
    }
    local shown = 0
    local setting = false
    local old_settings = G_reader_settings
    G_reader_settings = {
        isTrue = function(_, key)
            return key == UserPatches.NOTICE_SETTING and setting
        end,
        saveSetting = function(_, key, value)
            if key == UserPatches.NOTICE_SETTING then
                setting = value
            end
        end,
        flush = function() end,
    }
    withModules({
        ["ui/widget/notification"] = { new = function(_, options) return options end },
        ["ui/uimanager"] = { show = function(_, notice)
            shown = shown + 1
            for _, filename in ipairs(UserPatches.OWNED_PATCHES) do
                assertTruthy(notice.text:find(filename, 1, true), filename)
            end
            assertTruthy(notice.text:find("Remove these exact files", 1, true))
            assertTruthy(notice.text:find("restart KOReader", 1, true))
            assertEqual(notice.timeout, 8)
        end },
    }, function()
        assertEqual(UserPatches.showMigrationNotice(), true)
        assertEqual(UserPatches.showMigrationNotice(), false)
    end)
    G_reader_settings = old_settings
    UserPatches._test.reset()
    assertEqual(shown, 1)
end)

test("compatibility hands all patch ownership to Plain UI after removal and restart", function()
    local UserPatches = require("modules.compat.user_patches")
    local legacy_present = {}
    for _, filename in ipairs(UserPatches.OWNED_PATCHES) do
        legacy_present[filename] = true
    end
    local function initializeSession()
        UserPatches._test.reset()
        UserPatches.initialize{
            patches_dir = "/patches",
            file_exists = function(path)
                return legacy_present[path:match("([^/]+)$")] == true
            end,
        }
    end

    initializeSession()
    for _, filename in ipairs(UserPatches.OWNED_PATCHES) do
        assertEqual(UserPatches.isActive(filename), true, filename)
        legacy_present[filename] = false
    end

    -- Detection is deliberately stable for the running session.
    for _, filename in ipairs(UserPatches.OWNED_PATCHES) do
        assertEqual(UserPatches.isActive(filename), true, filename)
    end

    -- A restart creates a fresh compatibility session and enables the bundled
    -- implementations once the standalone patches are gone.
    initializeSession()
    for _, filename in ipairs(UserPatches.OWNED_PATCHES) do
        assertEqual(UserPatches.isActive(filename), false, filename)
    end
    UserPatches._test.reset()
end)

test("reading stats installation is idempotent and preserves legacy hooks", function()
    local registered = 0
    local function extend(_, definition)
        definition.__index = definition
        return definition
    end
    local gettext = setmetatable({
        ngettext = function(singular, plural, n)
            return n == 1 and singular or plural
        end,
    }, { __call = function(_, value) return value end })
    local stubs = {
        ["ffi/blitbuffer"] = {},
        ["ui/widget/container/centercontainer"] = {},
        ["datastorage"] = { getSettingsDir = function() return "/tmp" end },
        ["device"] = { screen = {} },
        ["dispatcher"] = { registerAction = function() registered = registered + 1 end },
        ["ui/font"] = {},
        ["ui/widget/container/framecontainer"] = {},
        ["ui/geometry"] = {},
        ["ui/gesturerange"] = {},
        ["ui/widget/horizontalgroup"] = {},
        ["ui/widget/horizontalspan"] = {},
        ["ui/widget/container/inputcontainer"] = { extend = extend },
        ["ui/widget/container/leftcontainer"] = {},
        ["ui/widget/linewidget"] = {},
        ["optmath"] = {},
        ["ui/widget/container/movablecontainer"] = {},
        ["lua-ljsqlite3/init"] = {},
        ["ui/size"] = {},
        ["ui/widget/textboxwidget"] = {},
        ["ui/widget/textwidget"] = {},
        ["ui/uimanager"] = {},
        ["util"] = {},
        ["ui/widget/verticalgroup"] = {},
        ["ui/widget/verticalspan"] = {},
        ["gettext"] = gettext,
    }
    local saved_service = package.loaded["modules.reader.reading_stats_popup"]
    package.loaded["modules.reader.reading_stats_popup"] = nil
    withModules(stubs, function()
        local Service = require("modules.reader.reading_stats_popup")
        local reader_ui = {}
        local installed, reason = Service.install(reader_ui)
        assertEqual(installed, true)
        assertEqual(reason, "installed")
        local handler = reader_ui.onShowReadingStatsPopup
        installed, reason = Service.install(reader_ui)
        assertEqual(installed, true)
        assertEqual(reason, "already_installed")
        assertEqual(reader_ui.onShowReadingStatsPopup, handler)
        assertEqual(registered, 1)

        local legacy_handler = function() end
        local legacy = {
            reading_stats_popup_patch_version = "1.1.0",
            onShowReadingStatsPopup = legacy_handler,
        }
        installed, reason = Service.install(legacy)
        assertEqual(installed, false)
        assertEqual(reason, "legacy_active")
        assertEqual(legacy.onShowReadingStatsPopup, legacy_handler)
        assertEqual(registered, 1)
    end)
    package.loaded["modules.reader.reading_stats_popup"] = saved_service
end)

test("shared status indicators map combined battery and Wi-Fi icon states", function()
    local frontlight_available = false
    local frontlight_on = false
    local power = {
        getCapacity = function() return 60 end,
        getAuxCapacity = function() return 40 end,
        isCharged = function() return false end,
        isCharging = function() return true end,
        isAuxCharged = function() return true end,
        isAuxCharging = function() return false end,
        isAuxBatteryConnected = function() return true end,
        isFrontlightOn = function() return frontlight_on end,
    }
    local stubs = {
        ["device"] = {
            screen = { night_mode = false },
            hasBattery = function() return true end,
            hasAuxBattery = function() return true end,
            hasWifiToggle = function() return true end,
            hasFrontlight = function() return frontlight_available end,
            getPowerDevice = function() return power end,
        },
        ["ui/event"] = {},
        ["ui/font"] = { getFace = function() return {} end },
        ["ui/widget/infomessage"] = {},
        ["ui/network/manager"] = { is_wifi_on = false },
        ["pluginloader"] = {},
        ["ui/widget/textwidget"] = { new = function(_, options)
            return {
                free = function() end,
                getSize = function() return { w = #options.text } end,
            }
        end },
        ["ui/uimanager"] = {},
    }
    withModules(stubs, function()
        package.loaded["modules.shared.status_indicators"] = nil
        local StatusIndicators = require("modules.shared.status_indicators")
        local battery = StatusIndicators.getCombinedBatteryState()
        assertEqual(battery.capacity, 50)
        assertEqual(battery.charged, false)
        assertEqual(battery.charging, true)
        assertEqual(StatusIndicators.getBatteryPercentageText(), "50%")
        assertEqual(StatusIndicators.getBatteryIconName(), "battery-vertical-charging")
        assertTruthy(StatusIndicators.getBatteryIconPath():find(
            "/icons/tabler/battery-vertical-charging.svg",
            1,
            true
        ))
        assertEqual(StatusIndicators.getWifiIconName(), "wifi-off")
        assertTruthy(StatusIndicators.getWifiIconPath():find(
            "/icons/tabler/wifi-off.svg",
            1,
            true
        ))
        assertTruthy(StatusIndicators.getNightModeIconPath():find(
            "/icons/tabler/moon.svg",
            1,
            true
        ))
        stubs["device"].screen.night_mode = true
        assertEqual(StatusIndicators.getNightModeIconName(), "moon-filled")
        assertEqual(StatusIndicators.getFrontlightIconName(), "bulb-off")
        frontlight_available = true
        frontlight_on = true
        assertEqual(StatusIndicators.getFrontlightIconName(), "bulb")

        local iconFor = StatusIndicators._test.getBatteryIconNameForState
        assertEqual(iconFor{ capacity = 0 }, "battery-vertical")
        assertEqual(iconFor{ capacity = 19 }, "battery-vertical")
        assertEqual(iconFor{ capacity = 20 }, "battery-vertical-1")
        assertEqual(iconFor{ capacity = 40 }, "battery-vertical-2")
        assertEqual(iconFor{ capacity = 60 }, "battery-vertical-3")
        assertEqual(iconFor{ capacity = 80 }, "battery-vertical-4")
        assertEqual(iconFor{ capacity = 100 }, "battery-vertical-4")
        assertEqual(iconFor{ capacity = 10, charging = true }, "battery-vertical-charging")
        assertEqual(iconFor{ capacity = 10, charged = true }, "battery-vertical-charged")

        local widths = StatusIndicators.getWidths("font", 12, 3, {
            night_mode = 20,
            frontlight = 20,
            wifi = 20,
            battery = 14,
        })
        assertEqual(widths.night_mode, 26)
        assertEqual(widths.frontlight, 26)
        assertEqual(widths.wifi, 26)
        assertEqual(widths.battery, 20)
    end)
    package.loaded["modules.shared.status_indicators"] = nil
end)

test("reader controller installs one swipe hook and restores it safely", function()
    local next_ticks = {}
    local closed = {}
    local ui_manager = {
        nextTick = function(_, callback)
            table.insert(next_ticks, callback)
        end,
        close = function(_, widget) table.insert(closed, widget) end,
        show = function() end,
    }
    withModules({
        ["ui/event"] = { new = function(_, name) return { name = name } end },
        ["logger"] = { info = function() end },
        ["ui/uimanager"] = ui_manager,
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local Controller = require("modules.reader.controller")
        local original = function() return "original" end
        local ui = { menu = { onSwipeShowMenu = original } }
        local controller = Controller.new({ path = "/plugin" }, ui)
        assertEqual(controller:installSwipeHandler(), true)
        local installed = ui.menu.onSwipeShowMenu
        assertEqual(controller:installSwipeHandler(), false)
        assertEqual(ui.menu.onSwipeShowMenu, installed)
        controller:stop()
        assertEqual(ui.menu.onSwipeShowMenu, original)

        controller = Controller.new({ path = "/plugin" }, ui)
        controller:installSwipeHandler()
        local later_hook = function() end
        ui.menu.onSwipeShowMenu = later_hook
        controller:stop()
        assertEqual(ui.menu.onSwipeShowMenu, later_hook)

        local popup = { name = "stats" }
        package.loaded["modules.reader.reading_stats_popup"] = {
            canShow = function() return true end,
            show = function(_, options)
                popup.options = options
                return popup
            end,
        }
        controller = Controller.new({ path = "/plugin" }, ui)
        controller.overlay = {
            selected_action = nil,
            setSelectedAction = function(self, action) self.selected_action = action end,
        }
        controller:showReadingStatsPopup(42)
        assertEqual(controller.stats_popup, popup)
        assertEqual(popup.options.top_offset, 42)
        controller:onSetDimensions()
        assertEqual(controller.stats_popup, nil)
        assertEqual(closed[1], popup)
        package.loaded["modules.reader.reading_stats_popup"] = nil
    end)
    package.loaded["modules.reader.controller"] = nil
end)

test("Plain UI reader controller is created only for rolling ReaderUI", function()
    local installed_stats = 0
    local controller_creations = 0
    local WidgetContainer = {}
    function WidgetContainer:extend(definition)
        definition.__index = definition
        return definition
    end
    local compat = {
        initialize = function() return {} end,
        isActive = function() return false end,
        showMigrationNotice = function() end,
    }
    local controller_module = {
        new = function(_, ui)
            controller_creations = controller_creations + 1
            return { ui = ui, onReaderReady = function() end }
        end,
    }
    withModules({
        ["ui/widget/container/widgetcontainer"] = WidgetContainer,
        ["modules.compat.user_patches"] = compat,
        ["modules.author_series"] = true,
        ["modules.metadata_tabs"] = true,
        ["modules.finished_badge"] = true,
        ["modules.reading_percentage"] = true,
        ["modules.reader.reading_stats_popup"] = { install = function() installed_stats = installed_stats + 1 end },
        ["modules.reader.controller"] = controller_module,
    }, function()
        local PlainUI = assert(loadfile("main.lua"))()
        local file_manager_plugin = setmetatable({ ui = {} }, PlainUI)
        assertEqual(file_manager_plugin:getReaderController(), nil)

        local reader_plugin = setmetatable({ path = "/plugin", ui = { rolling = {} } }, PlainUI)
        assertTruthy(reader_plugin:getReaderController())
        assertEqual(controller_creations, 1)
        assertTruthy(reader_plugin:getReaderController())
        assertEqual(controller_creations, 1)
        assertEqual(installed_stats, 1)
    end)
end)

test("Plain UI leaves every active legacy patch authoritative for the session", function()
    local WidgetContainer = {}
    function WidgetContainer:extend(definition)
        definition.__index = definition
        return definition
    end
    local active = {
        ["2-author-series.lua"] = true,
        ["2-filemanager-metadata-tabs.lua"] = true,
        ["2-finished-badge.lua"] = true,
        ["2-reading-percentage.lua"] = true,
        ["2-reading-stats-popup.lua"] = true,
    }
    local notices = 0
    local stats_installs = 0
    local bundled_modules = {
        "modules.author_series",
        "modules.metadata_tabs",
        "modules.finished_badge",
        "modules.reading_percentage",
        "modules.reader.reading_stats_popup",
    }
    withModules({
        ["ui/widget/container/widgetcontainer"] = WidgetContainer,
        ["modules.compat.user_patches"] = {
            initialize = function() return active end,
            isActive = function(filename) return active[filename] == true end,
            showMigrationNotice = function() notices = notices + 1 end,
        },
        ["modules.author_series"] = true,
        ["modules.metadata_tabs"] = true,
        ["modules.finished_badge"] = true,
        ["modules.reading_percentage"] = true,
        ["modules.reader.reading_stats_popup"] = {
            install = function() stats_installs = stats_installs + 1 end,
        },
    }, function()
        local PlainUI = assert(loadfile("main.lua"))()
        setmetatable({}, PlainUI):init()
        for _, module_name in ipairs(bundled_modules) do
            assertEqual(package.loaded[module_name], nil, module_name)
        end
        assertEqual(stats_installs, 0)
        assertEqual(notices, 1)
    end)
end)

test("active code never requires stale unnamespaced reader modules", function()
    local files = {
        "main.lua",
        "modules/metadata_tabs.lua",
        "modules/reader/controller.lua",
        "modules/reader/reader_overlay.lua",
        "modules/reader/typography_overlay.lua",
    }
    for _, filename in ipairs(files) do
        local handle = assert(io.open(filename, "r"))
        local source = handle:read("*a")
        handle:close()
        assertEqual(source:find('require("modules.status_indicators")', 1, true), nil, filename)
        assertEqual(source:find('require("modules.reader_overlay")', 1, true), nil, filename)
        assertEqual(source:find('require("modules.typography_overlay")', 1, true), nil, filename)
    end
end)

run()
