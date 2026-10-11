-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Event = require("ui/event")
local logger = require("logger")
local UIManager = require("ui/uimanager")

local Controller = {}
Controller.__index = Controller

function Controller.new(plugin, ui)
    return setmetatable({
        owner = plugin,
        path = plugin.path,
        ui = ui,
        overlay = nil,
        original_on_swipe_show_menu = nil,
        stats_popup = nil,
        installed_swipe_handler = nil,
        typography_overlay = nil,
    }, Controller)
end

function Controller:installSwipeHandler()
    if self.installed_swipe_handler or not self.ui or not self.ui.menu then
        return false
    end
    self.original_on_swipe_show_menu = self.ui.menu.onSwipeShowMenu
    self.installed_swipe_handler = function(_, ges)
        return self:onSwipeShowOverlay(ges)
    end
    self.ui.menu.onSwipeShowMenu = self.installed_swipe_handler
    logger.info("PlainUI: installed reader menu swipe handler")
    return true
end

function Controller:onReaderReady()
    local TypographyOverlay = require("modules.reader.typography_overlay")
    TypographyOverlay.installCommonAlignmentTweaks(self.ui, true)
    self:installSwipeHandler()
    self:installBottomNavigationHandler()
    if not self.navigation_history then
        self.navigation_history = require("modules.reader.navigation_history").new(self.ui)
        self.navigation_history:install()
    end
end

function Controller:installBottomNavigationHandler()
    local config = self.ui and self.ui.config
    if not config or self.installed_config_handler then return false end
    self.original_config_own = rawget(config, "onShowConfigMenu")
    self.original_config_handler = config.onShowConfigMenu
    self.original_config_swipe_own = rawget(config, "onSwipeShowConfigMenu")
    self.installed_config_handler = function()
        self:showBottomNavigation()
        return true
    end
    self.installed_config_swipe = function(_, ges)
        if not ges or ges.direction ~= "north" then return end
        -- ReaderConfig also dispatches pan to its swipe handler. Wait for
        -- finger release, so the opening drag cannot activate the chevron.
        if ges.ges ~= "pan" and ges.ges ~= "hold_pan" then self:showBottomNavigation() end
        self.ui:handleEvent(Event:new("HandledAsSwipe"))
        return true
    end
    config.onShowConfigMenu = self.installed_config_handler
    config.onSwipeShowConfigMenu = self.installed_config_swipe
    return true
end

function Controller:showBottomNavigation()
    if self.bottom_navigation or not self.ui or not self.ui.thumbnail then return end
    self:closeReadingStatsPopup()
    self:closeTypographyOverlay()
    self:closeOverlay()
    local BottomNavigation = require("modules.reader.bottom_navigation")
    self.bottom_navigation = BottomNavigation:new{ plugin = self }
    UIManager:show(self.bottom_navigation)
end

function Controller:closeBottomNavigation()
    local widget = self.bottom_navigation
    if not widget then return end
    self.bottom_navigation = nil
    UIManager:close(widget)
end

function Controller:commitNavigationPreview(page)
    self:closeBottomNavigation()
    if page == self.ui:getCurrentPage() then return end
    self.ui.link:addCurrentLocationToStack()
    self.ui:handleEvent(Event:new("GotoPage", page))
end

function Controller:hasAnchoredReadingStatsPopup()
    return require("modules.reader.reading_stats_popup").canShow(self.ui)
end

function Controller:showReadingStatsPopup(top_offset)
    local ReadingStatsPopup = require("modules.reader.reading_stats_popup")
    if not ReadingStatsPopup.canShow(self.ui) then
        return
    end
    self:closeReadingStatsPopup()
    self:setToolbarSelected("stats")
    local popup
    popup = ReadingStatsPopup.show(self.ui, {
        close_callback = function()
            if self.stats_popup == popup then
                self.stats_popup = nil
            end
            self:setToolbarSelected(nil, "stats")
        end,
        replacement_callback = function(replacement)
            if self.stats_popup == popup then
                self.stats_popup = replacement
                popup = replacement
            end
        end,
        top_offset = top_offset,
        toolbar_tap_callback = function(pos)
            return self:switchToolbarAction(pos, "stats")
        end,
    })
    if type(popup) == "table" then
        self.stats_popup = popup
    end
    self:repaintToolbarSelected("stats")
end

function Controller:closeReadingStatsPopup()
    if not self.stats_popup then
        return
    end
    local popup = self.stats_popup
    self.stats_popup = nil
    UIManager:close(popup)
end

function Controller:setToolbarSelected(action_id, expected_current)
    local overlay = self.overlay
    if not overlay then
        return
    end
    if expected_current and overlay.selected_action ~= expected_current then
        return
    end
    overlay:setSelectedAction(action_id)
end

function Controller:repaintToolbarSelected(action_id, expected_popup)
    local overlay = self.overlay
    UIManager:nextTick(function()
        if self.overlay == overlay
                and overlay.selected_action == action_id
                and (not expected_popup or self.typography_overlay == expected_popup) then
            overlay:setSelectedAction(action_id, true)
        end
    end)
end

function Controller:switchToolbarAction(pos, current_action)
    local overlay = self.overlay
    local button = overlay and overlay:getToolbarActionAt(pos)
    if not button then
        return false
    end

    self:closeTypographyOverlay()
    if button.action_id == current_action then
        return true
    end
    UIManager:nextTick(function()
        if self.overlay == overlay then
            overlay:triggerToolbarAction(button)
        end
    end)
    return true
end

function Controller:onSetDimensions()
    self:closeBottomNavigation()
    self:closeReadingStatsPopup()
    self:closeOverlay()
    self:closeTypographyOverlay()
    if self.navigation_history then self.navigation_history:onSetDimensions() end
end

function Controller:onSwipeShowOverlay(ges)
    if not ges or ges.direction ~= "south" then
        return
    end
    self:showOverlay()
    self.ui:handleEvent(Event:new("HandledAsSwipe"))
    return true
end

function Controller:showOverlay()
    self:closeBottomNavigation()
    if self.overlay then
        return
    end
    local ReaderOverlay = require("modules.reader.reader_overlay")
    self.overlay = ReaderOverlay:new{
        plugin = self,
    }
    UIManager:show(self.overlay)
end

function Controller:closeOverlay()
    if not self.overlay then
        return
    end
    local overlay = self.overlay
    self.overlay = nil
    UIManager:close(overlay)
end

function Controller:showTypographyOverlay(options)
    if self.typography_overlay or not self.ui or not self.ui.rolling then
        return
    end
    self:closeReadingStatsPopup()
    options = options or {}
    local top_offset = options.top_offset
    if not top_offset and self.overlay and self.overlay.panel then
        top_offset = self.overlay.panel:getSize().h
    end
    local TypographyOverlay = require("modules.reader.typography_overlay")
    self.typography_overlay = TypographyOverlay:new{
        font_page = options.font_page,
        font_picker_expanded = options.font_picker_expanded,
        plugin = self,
        top_offset = top_offset,
    }
    local typography_overlay = self.typography_overlay
    self:setToolbarSelected("typography")
    UIManager:show(typography_overlay)
    self:repaintToolbarSelected("typography", typography_overlay)
end

function Controller:replaceTypographyOverlay(options)
    UIManager:nextTick(function()
        if self.typography_overlay then
            self:closeTypographyOverlay()
        end
        UIManager:nextTick(function()
            if self.ui and self.ui.document then
                self:showTypographyOverlay(options)
            end
        end)
    end)
end

function Controller:closeTypographyOverlay()
    if not self.typography_overlay then
        return
    end
    local overlay = self.typography_overlay
    self.typography_overlay = nil
    UIManager:close(overlay)
end

function Controller:showFullConfigMenu()
    self:closeReadingStatsPopup()
    self:closeTypographyOverlay()
    self:closeBottomNavigation()
    if self.original_config_handler then
        return self.original_config_handler(self.ui.config)
    end
    self.ui:handleEvent(Event:new("ShowConfigMenu"))
end

function Controller:showDefaultMenu()
    self:closeReadingStatsPopup()
    self:closeOverlay()
    self.ui:handleEvent(Event:new("ShowMenu"))
end

function Controller:showTableOfContents()
    self:closeReadingStatsPopup()
    self:closeOverlay()
    self.ui:handleEvent(Event:new("ShowToc"))
end

function Controller:showFulltextSearch()
    self:closeReadingStatsPopup()
    self:closeOverlay()
    self.ui:handleEvent(Event:new("ShowFulltextSearchInput"))
end

function Controller:backToFileManager()
    self:closeReadingStatsPopup()
    self:closeOverlay()
    local file = self.ui.document.file
    self.ui:onClose()
    self.ui:showFileManager(file)
end

function Controller:stop()
    self:closeBottomNavigation()
    local config = self.ui and self.ui.config
    if config and self.installed_config_handler then
        if config.onShowConfigMenu == self.installed_config_handler then
            config.onShowConfigMenu = self.original_config_own
        end
        if config.onSwipeShowConfigMenu == self.installed_config_swipe then
            config.onSwipeShowConfigMenu = self.original_config_swipe_own
        end
    end
    self.installed_config_handler, self.installed_config_swipe = nil, nil
    self.original_config_handler = nil
    if self.navigation_history then
        self.navigation_history:stop()
        self.navigation_history = nil
    end
    self:closeReadingStatsPopup()
    self:closeOverlay()
    self:closeTypographyOverlay()
    if self.ui and self.ui.menu
            and self.installed_swipe_handler
            and self.ui.menu.onSwipeShowMenu == self.installed_swipe_handler then
        self.ui.menu.onSwipeShowMenu = self.original_on_swipe_show_menu
    end
    self.original_on_swipe_show_menu = nil
    self.installed_swipe_handler = nil
end

return Controller
