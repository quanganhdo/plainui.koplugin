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

test("statistics patches and their markers do not trigger migration", function()
    local UserPatches = require("modules.compat.user_patches")
    local signals = {
        { reading_stats_popup_patch_version = "1.1.0" },
        { reading_stats_popup_api_version = 2 },
        { onShowReadingStatsPopup = function() end },
    }
    for _, reader_ui in ipairs(signals) do
        local detected = UserPatches.detect{
            patches_dir = "/missing",
            file_exists = function(path) return path:match("2%-reading%-stats%-popup.lua$") ~= nil end,
            reader_ui = reader_ui,
        }
        assertEqual(#detected, 0)
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

test("reading stats installation uses its own action and preserves external hooks", function()
    local registered = {}
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
        ["dispatcher"] = { registerAction = function(_, name, action)
            registered[name] = registered[name] or action
        end },
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
        local handler = reader_ui.onShowPlainUIBookOverview
        installed, reason = Service.install(reader_ui)
        assertEqual(installed, true)
        assertEqual(reason, "already_installed")
        assertEqual(reader_ui.onShowPlainUIBookOverview, handler)
        assertEqual(reader_ui.onShowReadingStatsPopup, nil)
        assertEqual(registered.plainui_book_overview.event, "ShowPlainUIBookOverview")
        assertEqual(registered.plainui_book_overview.title, "Plain UI: book overview")
        assertEqual(registered.reading_stats_popup, nil)

        local legacy_handler = function() end
        local legacy = {
            reading_stats_popup_patch_version = "1.1.0",
            onShowReadingStatsPopup = legacy_handler,
        }
        installed, reason = Service.install(legacy)
        assertEqual(installed, true)
        assertEqual(reason, "installed")
        assertEqual(legacy.onShowReadingStatsPopup, legacy_handler)
        assertEqual(legacy.reading_stats_popup_patch_version, "1.1.0")
        assertEqual(legacy.reading_stats_popup_api_version, nil)
        assertTruthy(legacy.onShowPlainUIBookOverview)
        assertEqual(Service.canShow(legacy), true)
        assertEqual(Service.canShow({onShowReadingStatsPopup = legacy_handler}), true)
        Service.registerLegacyAlias(legacy)
        assertEqual(registered.reading_stats_popup, nil)
        Service.registerLegacyAlias(reader_ui)
        assertEqual(registered.reading_stats_popup.event, "ShowPlainUIBookOverview")
        assertEqual(registered.reading_stats_popup.reader, nil)
        registered.reading_stats_popup = {event = "ExternalBookProgress"}
        Service.registerLegacyAlias(reader_ui)
        assertEqual(registered.reading_stats_popup.event, "ExternalBookProgress")
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
        local plugins = stubs["pluginloader"]
        plugins.isPluginLoaded = function(self, name)
            assertEqual(name, "batterystat")
            return self.loaded_plugins[name] ~= nil
        end
        assertEqual(StatusIndicators.hasBatteryStatistics(), false)
        plugins.loaded_plugins = {}
        assertEqual(StatusIndicators.hasBatteryStatistics(), false)
        plugins.loaded_plugins.batterystat = {}
        assertEqual(StatusIndicators.hasBatteryStatistics(), true)
        plugins.loaded_plugins.batterystat = nil
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

        local network = stubs["ui/network/manager"]
        local called, refreshed
        network.queryNetworkState = function() end
        network.toggleWifiOff = function(_, callback, interactive)
            called = "off"
            assertEqual(interactive, true)
            callback()
        end
        network.toggleWifiOn = function(_, callback, long_press, interactive)
            called = "on"
            assertEqual(long_press, nil)
            assertEqual(interactive, true)
            callback()
        end
        for _, case in ipairs({ {true, false, "off"}, {false, true, "on"},
                {true, true, nil}, {false, false, nil} }) do
            network.is_wifi_on, network.is_connected = case[1], false
            called, refreshed = nil, 0
            StatusIndicators.setWifiEnabled(case[2], function() refreshed = refreshed + 1 end)
            assertEqual(called, case[3])
            assertEqual(refreshed, 1)
        end
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

test("reader ready leaves status bars untouched and installs the swipe overlay", function()
    local alignment_tweaks_installed = false
    local handled_events = 0
    local footer_settings = { disabled = true, battery = true, time = true }
    withModules({
        ["ui/event"] = {
            new = function(_, name) return { name = name } end,
        },
        ["logger"] = { info = function() end },
        ["modules.reader.typography_overlay"] = {
            installCommonAlignmentTweaks = function(_, apply)
                alignment_tweaks_installed = apply == true
            end,
        },
        ["ui/uimanager"] = {},
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local Controller = require("modules.reader.controller")
        local ui = {
            rolling = {},
            handleEvent = function() handled_events = handled_events + 1 end,
            menu = { onSwipeShowMenu = function() end },
            view = { footer = { settings = footer_settings } },
        }
        local controller = Controller.new({ path = "/plugin" }, ui)
        local original_swipe_handler = ui.menu.onSwipeShowMenu
        controller:onReaderReady()

        assertEqual(handled_events, 0)
        assertEqual(ui.view.footer.settings, footer_settings)
        assertEqual(footer_settings.disabled, true)
        assertEqual(footer_settings.battery, true)
        assertEqual(footer_settings.time, true)
        assertEqual(alignment_tweaks_installed, true)
        assertTruthy(ui.menu.onSwipeShowMenu ~= original_swipe_handler)
    end)
    package.loaded["modules.reader.controller"] = nil
end)

test("fixed-page reader installs navigation without loading typography or profiles", function()
    withModules({
        ["ui/event"] = { new = function(_, name) return { name = name } end },
        ["logger"] = { info = function() end },
        ["ui/uimanager"] = {},
        ["modules.reader.typography_overlay"] = {
            installCommonAlignmentTweaks = function() error("PDF must not apply text tweaks") end,
        },
        ["modules.reader.typography_settings"] = {
            defaults = function() error("PDF must not create typography profiles") end,
        },
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local Controller = require("modules.reader.controller")
        local ui = { paging = {}, font = {}, typeset = {}, doc_settings = {},
            document = { configurable = {} }, menu = { onSwipeShowMenu = function() end },
            config = { onShowConfigMenu = function() end } }
        local c = Controller.new({ path = "/plugin" }, ui)
        c:onReaderReady()
        assertTruthy(c.installed_swipe_handler)
        assertTruthy(c.installed_config_handler)
        assertEqual(c.typography_profiles, nil)
        assertEqual(c:ensureTypographyProfiles(), nil)
        c:stop()
    end)
    package.loaded["modules.reader.controller"] = nil
end)

test("Plain UI reader controller supports rolling and paging documents, including legacy opt-out settings", function()
    local installed_stats = 0
    local controller_creations = 0
    local controller_stops = 0
    local history_refreshes = 0
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
            return {
                ui = ui,
                onReaderReady = function() end,
                navigation_history = {
                    active = true,
                    queueRefresh = function() history_refreshes = history_refreshes + 1 end,
                },
                stop = function() controller_stops = controller_stops + 1 end,
            }
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
        local fixed_layout_plugin = setmetatable({ ui = { paging = {} } }, PlainUI)
        assertTruthy(fixed_layout_plugin:getReaderController())
        assertEqual(controller_creations, 1)

        local reader_plugin = setmetatable({ path = "/plugin", ui = { rolling = {} } }, PlainUI)
        assertTruthy(reader_plugin:getReaderController())
        assertEqual(controller_creations, 2)
        assertTruthy(reader_plugin:getReaderController())
        assertEqual(controller_creations, 2)
        assertEqual(installed_stats, 1)
        reader_plugin:onPageUpdate()
        assertEqual(history_refreshes, 1)
        reader_plugin.reader_controller.navigation_history.active = false
        reader_plugin:onPageUpdate()
        assertEqual(history_refreshes, 1)
        reader_plugin:onCloseDocument()
        assertEqual(controller_stops, 1)
        assertEqual(reader_plugin.reader_controller, nil)
        local original_settings = G_reader_settings
        G_reader_settings = {
            isFalse = function(_, key) return key == "plainui_reader_enabled" end,
            readSetting = function(_, key) if key == "plainui_reader_enabled" then return false end end,
        }
        assertTruthy(reader_plugin:getReaderController())
        assertEqual(controller_creations, 3)
        G_reader_settings = original_settings
    end)
end)

test("Plain UI installs its overview alongside active statistics patches", function()
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
        assertEqual(stats_installs, 1)
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

test("bottom menu hooks open previews and chevron bypasses the hook", function()
    local native_calls, shown, closes, pushed, events = 0, 0, 0, 0, {}
    local native = function() native_calls = native_calls + 1; return true end
    local class = { onShowConfigMenu = native, onSwipeShowConfigMenu = function() end }
    local config = setmetatable({}, { __index = class })
    withModules({
        ["ui/event"] = { new = function(_, name, value) return { name = name, value = value } end },
        ["logger"] = { info = function() end },
        ["ui/uimanager"] = {
            show = function() shown = shown + 1 end,
            close = function() closes = closes + 1 end,
        },
        ["modules.reader.bottom_navigation"] = { new = function(_, options) return options end },
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local Controller = require("modules.reader.controller")
        local ui = {
            config = config, thumbnail = {}, getCurrentPage = function() return 25 end,
            link = { addCurrentLocationToStack = function() pushed = pushed + 1 end },
            handleEvent = function(_, event) events[#events + 1] = event end,
        }
        local c = Controller.new({path = "/plugin"}, ui)
        assertEqual(c:installBottomNavigationHandler(), true)
        assertEqual(c:installBottomNavigationHandler(), false)
        config:onSwipeShowConfigMenu{ges = "pan", direction = "north"}
        assertEqual(shown, 0)
        config:onSwipeShowConfigMenu{ges = "swipe", direction = "north"}
        assertEqual(shown, 1)
        assertEqual(native_calls, 0)
        assertEqual(pushed, 0)
        c:showFullConfigMenu()
        assertEqual(native_calls, 1)
        assertEqual(closes, 1)
        config:onShowConfigMenu()
        c:commitNavigationPreview(25)
        assertEqual(pushed, 0)
        config:onShowConfigMenu()
        c:commitNavigationPreview(75)
        assertEqual(pushed, 1)
        assertEqual(events[#events].name, "GotoPage")
        assertEqual(events[#events].value, 75)
        c:stop()
        assertEqual(rawget(config, "onShowConfigMenu"), nil)
        assertEqual(rawget(config, "onSwipeShowConfigMenu"), nil)
        assertEqual(config.onShowConfigMenu, native)
        c:installBottomNavigationHandler()
        local later = function() end
        config.onShowConfigMenu = later
        c:stop()
        assertEqual(config.onShowConfigMenu, later)
    end)
    package.loaded["modules.reader.controller"] = nil
end)

test("native navigation panels retain the preview until an actual navigation event", function()
    local actions = {}
    withModules({
        ["ui/event"] = {new = function(_, name) return {name = name, handler = "on" .. name} end},
        ["logger"] = {info = function() end},
        ["ui/uimanager"] = {close = function(_, widget) actions[#actions + 1] = widget.name end},
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local c = require("modules.reader.controller").new({path = "/plugin"}, {
            handleEvent = function(_, event) actions[#actions + 1] = event.name end,
        })
        for _, pair in ipairs{{"showGotoDialog", "ShowGotoDialog"}, {"showBookmarks", "ShowBookmark"}, {"showTableOfContents", "ShowToc"}, {"showFulltextSearch", "ShowFulltextSearchInput"}} do
            actions = {}
            local preview = {name = "preview", model = {page = 70, origin = 25}}
            c.bottom_navigation = preview
            c:installPreviewNavigationHandler()
            c.overlay = {name = "toolbar"}
            c[pair[1]](c)
            assertEqual(c.bottom_navigation, preview)
            assertEqual(preview.model.page, 70)
            assertEqual(preview.model.origin, 25)
            assertEqual(c.overlay, nil)
            assertEqual(actions[1], "toolbar")
            assertEqual(actions[2], pair[2])
            c.ui:handleEvent{handler = "onGotoPage", name = "GotoPage"}
            assertEqual(c.bottom_navigation, nil)
            assertEqual(actions[3], "preview")
            assertEqual(actions[4], "GotoPage")
        end
    end)
    package.loaded["modules.reader.controller"] = nil
end)

test("preview navigation hooks restore inherited handlers and respect later hooks", function()
    withModules({
        ["ui/event"] = {}, ["logger"] = {},
        ["ui/uimanager"] = {close = function() end},
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local Controller = require("modules.reader.controller")
        local original = function() return "handled" end
        local ui = setmetatable({}, {__index = {handleEvent = original}})
        local push = function() return "pushed" end
        ui.link = setmetatable({}, {__index = {addCurrentLocationToStack = push}})
        local c = Controller.new({path = "/plugin"}, ui)
        for _, handler in ipairs{"onGotoPage", "onGotoXPointer", "onGotoPercent", "onGotoRelativePage", "onRestoreBookLocation"} do
            c.bottom_navigation = {}
            c:installPreviewNavigationHandler()
            c:installPreviewNavigationHandler()
            assertEqual(ui:handleEvent{handler = "onAnnotationsModified"}, "handled")
            assertTruthy(c.bottom_navigation)
            assertEqual(ui:handleEvent{handler = handler}, "handled")
            assertEqual(c.bottom_navigation, nil)
            assertEqual(rawget(ui, "handleEvent"), nil)
            assertEqual(ui.handleEvent, original)
            assertEqual(rawget(ui.link, "addCurrentLocationToStack"), nil)
            assertEqual(ui.link.addCurrentLocationToStack, push)
        end
        c.bottom_navigation = {}
        c:installPreviewNavigationHandler()
        assertEqual(ui.link:addCurrentLocationToStack(), "pushed")
        assertEqual(c.bottom_navigation, nil)
        assertEqual(ui.link.addCurrentLocationToStack, push)
        c.bottom_navigation = {}
        c:installPreviewNavigationHandler()
        local later = function() end
        ui.handleEvent = later
        c:closeBottomNavigation()
        assertEqual(ui.handleEvent, later)
    end)
    package.loaded["modules.reader.controller"] = nil
end)

test("preview bookmarking updates the selected page and the actual reader dogear separately", function()
    withModules({
        ["ui/event"] = {}, ["logger"] = {},
        ["ui/uimanager"] = {setDirty = function() end},
    }, function()
        package.loaded["modules.reader.controller"] = nil
        local toggled, dogear, footer_updates
        local c = require("modules.reader.controller").new({path = "/plugin"}, {
            bookmark = {
                toggleBookmark = function(_, page) toggled = page end,
                getCurrentPageNumber = function() return "reading-position" end,
                setDogearVisibility = function(_, xp) dogear = xp end,
            },
            view = {footer = {maybeUpdateFooter = function() footer_updates = true end}},
        })
        c.bottom_navigation = {preview_bookmark_button = {}}
        c:togglePreviewBookmark(70)
        assertEqual(toggled, 70)
        assertEqual(dogear, "reading-position")
        assertEqual(footer_updates, true)
        assertTruthy(c.bottom_navigation)
    end)
    package.loaded["modules.reader.controller"] = nil
end)

run()
