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
    self:ensureTypographyProfiles()
    self:installSwipeHandler()
    self:installBottomNavigationHandler()
    if not self.navigation_history then
        self.navigation_history = require("modules.reader.navigation_history").new(self.ui)
        self.navigation_history:install()
    end
end

function Controller:ensureTypographyProfiles()
    if self.typography_profiles then return self.typography_profiles end
    local ui = self.ui
    if not ui or not ui.doc_settings or not ui.font or not ui.typeset
            or not ui.document or not ui.document.configurable then return end
    local Settings = require("modules.reader.typography_settings")
    local Profiles = require("modules.reader.typography_profiles")
    self.typography_profiles = Profiles.new(G_reader_settings, ui.doc_settings,
        Settings.defaults(ui), Settings.capture(ui))
    Settings.apply(ui, self.typography_profiles.current)
    self.typography_profiles:record(Settings.capture(ui))
    return self.typography_profiles
end

function Controller:recordTypographySettings()
    if self.typography_profiles and self.ui and self.ui.document then
        self.typography_profiles:record(require("modules.reader.typography_settings").capture(self.ui))
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
    self:installPreviewNavigationHandler()
    UIManager:show(self.bottom_navigation)
end

function Controller:installPreviewNavigationHandler()
    if self.preview_navigation_handler then return end
    local original = self.ui.handleEvent
    if type(original) ~= "function" then return end
    local navigation_events = {
        onGotoPage = true, onGotoXPointer = true,
        onGotoPercent = true, onGotoRelativePage = true, onRestoreBookLocation = true,
    }
    self.preview_navigation_original = rawget(self.ui, "handleEvent")
    self.preview_navigation_handler = function(ui, event, ...)
        if event and navigation_events[event.handler] then self:closeBottomNavigation() end
        return original(ui, event, ...)
    end
    self.ui.handleEvent = self.preview_navigation_handler
    -- Search results can navigate through ReaderRolling directly. Native
    -- destination selection still pushes history before making that jump.
    local link = self.ui.link
    if link and type(link.addCurrentLocationToStack) == "function" then
        local push = link.addCurrentLocationToStack
        self.preview_history_original = rawget(link, "addCurrentLocationToStack")
        self.preview_history_handler = function(object, ...)
            self:closeBottomNavigation()
            return push(object, ...)
        end
        link.addCurrentLocationToStack = self.preview_history_handler
    end
end

function Controller:restorePreviewNavigationHandler()
    if self.preview_navigation_handler
            and self.ui.handleEvent == self.preview_navigation_handler then
        self.ui.handleEvent = self.preview_navigation_original
    end
    self.preview_navigation_handler, self.preview_navigation_original = nil, nil
    local link = self.ui.link
    if self.preview_history_handler and link.addCurrentLocationToStack == self.preview_history_handler then
        link.addCurrentLocationToStack = self.preview_history_original
    end
    self.preview_history_handler, self.preview_history_original = nil, nil
end

function Controller:closeBottomNavigation()
    local widget = self.bottom_navigation
    self:restorePreviewNavigationHandler()
    if not widget then return end
    self.bottom_navigation = nil
    UIManager:close(widget)
end

function Controller:togglePreviewBookmark(page)
    local bookmark = self.ui.bookmark
    if not bookmark then return end
    bookmark:toggleBookmark(page)
    bookmark:setDogearVisibility(bookmark:getCurrentPageNumber())
    self.ui.view.footer:maybeUpdateFooter()
    if self.bottom_navigation then
        UIManager:setDirty(self.bottom_navigation, "ui", self.bottom_navigation.preview_bookmark_button)
    end
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
    self:closeRecentBooksMenu()
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

    self:closeRecentBooksMenu()
    self:closeMoreMenu()
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
    self:closeMoreMenu()
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
    self:closeRecentBooksMenu()
    self:closeMoreMenu()
    if not self.overlay then
        return
    end
    local overlay = self.overlay
    self.overlay = nil
    UIManager:close(overlay)
end

function Controller:showTypographyOverlay(options)
    self:closeRecentBooksMenu()
    self:closeMoreMenu()
    if self.typography_overlay or not self.ui or not self.ui.rolling then
        return
    end
    self:closeReadingStatsPopup()
    options = options or {}
    self:ensureTypographyProfiles()
    self:recordTypographySettings()
    local top_offset = options.top_offset
    if not top_offset and self.overlay and self.overlay.panel then
        top_offset = self.overlay:getTypographyTopOffset()
    end
    if self.overlay then self.overlay.typography_active = true end
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
    self:recordTypographySettings()
    self.typography_overlay = nil
    UIManager:close(overlay)
end

function Controller:showFullConfigMenu()
    self:closeRecentBooksMenu()
    self:closeMoreMenu()
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

function Controller:showMoreMenu(anchor)
    if self.more_menu then self:closeMoreMenu(); return end
    self:closeRecentBooksMenu()
    self:closeReadingStatsPopup()
    self:closeTypographyOverlay()
    local MoreMenu = require("modules.reader.more_menu")
    self.more_menu = MoreMenu:new{ plugin = self, anchor = anchor and anchor:copy() }
    self:setToolbarSelected("more")
    UIManager:show(self.more_menu)
end

function Controller:closeMoreMenu()
    if not self.more_menu then return end
    local menu = self.more_menu
    self.more_menu = nil
    UIManager:close(menu)
end

function Controller:showRecentBooksMenu(anchor)
    if self.recent_books_menu then self:closeRecentBooksMenu(); return end
    self:closeMoreMenu()
    self:closeReadingStatsPopup()
    self:closeTypographyOverlay()
    local Menu = require("modules.reader.recent_books_menu")
    self.recent_books_menu = Menu:new{ plugin = self, anchor = anchor and anchor:copy() }
    self:setToolbarSelected("recent_books")
    UIManager:show(self.recent_books_menu)
end

function Controller:closeRecentBooksMenu()
    if not self.recent_books_menu then return end
    local menu = self.recent_books_menu
    self.recent_books_menu = nil
    UIManager:close(menu)
end

function Controller:openRecentBook(file)
    self:closeRecentBooksMenu()
    if not file or file == self.ui.document.file then return end
    if require("libs/libkoreader-lfs").attributes(file, "mode") ~= "file" then
        local _ = require("gettext")
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("This book is no longer available.") })
        return
    end
    self:closeReadingStatsPopup()
    self:closeTypographyOverlay()
    self:closeOverlay()
    self.ui:switchDocument(file)
end

function Controller:showReadingHistory()
    self:closeReadingStatsPopup()
    self:closeTypographyOverlay()
    self:closeOverlay()
    self.ui.history:onShowHist()
end

function Controller:runMoreAction(key)
    -- Recheck native capabilities and sync configuration at selection time.
    local items = require("modules.reader.more_actions").getItems(self.ui)
    self:closeMoreMenu()
    for _, item in ipairs(items) do
        if item.key == key then
            self:closeOverlay()
            if key == "disable_touch" then
                local ConfirmBox = require("ui/widget/confirmbox")
                local _ = require("gettext")
                UIManager:show(ConfirmBox:new{
                    text = require("modules.reader.more_actions").getTouchInstructions(),
                    ok_text = _("Disable"),
                    ok_callback = function()
                        self.ui:handleEvent(Event:new(item.event, item.arg))
                    end,
                })
                return true
            end
            self.ui:handleEvent(Event:new(item.event, item.arg))
            return true
        end
    end
    return false
end

function Controller:showNavigationPanel(event)
    self:closeReadingStatsPopup()
    self:closeOverlay()
    -- Retain the preview beneath native panels, including nested dialogs and
    -- search results. Cancelling reveals it unchanged; a navigation event
    -- closes it before the reader jumps, even if the destination is unchanged.
    self.ui:handleEvent(Event:new(event))
end

function Controller:showGotoDialog()
    self:showNavigationPanel("ShowGotoDialog")
end

function Controller:showBookmarks()
    self:showNavigationPanel("ShowBookmark")
end

function Controller:showTableOfContents()
    self:showNavigationPanel("ShowToc")
end

function Controller:showFulltextSearch()
    self:showNavigationPanel("ShowFulltextSearchInput")
end

function Controller:backToFileManager()
    self:closeReadingStatsPopup()
    self:closeOverlay()
    local file = self.ui.document.file
    self.ui:onClose()
    self.ui:showFileManager(file)
end

function Controller:stop()
    self:recordTypographySettings()
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
