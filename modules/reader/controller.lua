-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Event = require("ui/event")
local logger = require("logger")
local UIManager = require("ui/uimanager")

local Controller = {}
Controller.__index = Controller

local FOOTER_CONTENT_ITEMS = {
    "additional_content",
    "battery",
    "book_author",
    "book_chapter",
    "book_time_to_read",
    "book_title",
    "bookmark_count",
    "chapter_progress",
    "chapter_time_to_read",
    "custom_text",
    "dynamic_filler",
    "dynamic_filler2",
    "frontlight",
    "frontlight_warmth",
    "mem_usage",
    "page_progress",
    "page_turning_inverted",
    "pages_left",
    "pages_left_book",
    "percentage",
    "time",
    "wifi_status",
}

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(copy, getmetatable(value))
end

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
    self:enforceReaderChrome()
    TypographyOverlay.installCommonAlignmentTweaks(self.ui, true)
    self:installSwipeHandler()
end

function Controller:enforceReaderChrome()
    if not self.ui then
        return false
    end

    -- CRe uses 1 for hidden and 0 for visible. Apply this only to the live
    -- document: do not touch its configurable value or either settings store.
    self.ui:handleEvent(Event:new("SetStatusLine", 1))

    local footer = self.ui.view and self.ui.view.footer
    if not footer or not footer.settings or not footer.progress_bar then
        logger.warn("PlainUI: cannot apply reader footer layout")
        return false
    end

    -- ReaderFooter.settings normally aliases the table in G_reader_settings.
    -- Detach it before applying Plain UI's session-only presentation.
    local settings = deepCopy(footer.settings)
    for _, item in ipairs(FOOTER_CONTENT_ITEMS) do
        settings[item] = false
    end
    settings.disabled = false
    settings.all_at_once = true
    settings.auto_refresh_time = true
    settings.book_chapter = true
    settings.chapter_time_to_read = true
    settings.dynamic_filler = true
    settings.disable_progress_bar = false
    settings.chapter_progress_bar = false
    settings.hide_empty_generators = true
    settings.lock_tap = false
    settings.progress_bar_position = "below"
    settings.progress_style_thin = true
    settings.order = {
        [0] = "off",
        [1] = "book_chapter",
        [2] = "dynamic_filler",
        [3] = "chapter_time_to_read",
    }
    footer.settings = settings

    footer:set_mode_index()
    footer:set_has_no_mode()
    footer.progress_bar:updateStyle(false, settings.progress_style_thin_height)
    footer:updateFooterTextGenerator()
    footer:applyFooterMode(footer.mode_list.page_progress)
    footer:setTocMarkers()
    footer:refreshFooter(true, true)
    footer:rescheduleFooterAutoRefreshIfNeeded()
    return true
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
    self:closeReadingStatsPopup()
    self:closeOverlay()
    self:closeTypographyOverlay()
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
