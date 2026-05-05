-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local userpatch = require("userpatch")
local Button = require("ui/widget/button")
local Device = require("device")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local FileChooser = require("ui/widget/filechooser")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local LeftContainer = require("ui/widget/container/leftcontainer")
local MetadataFacetDropdown = require("modules.metadata_facet_dropdown")
local NetworkMgr = require("ui/network/manager")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local StatusIndicators = require("modules.status_indicators")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local VirtualPath = require("modules.virtual_path")
local _ = require("gettext")
local Screen = Device.screen
local Size = require("ui/size")

local DGENERIC_ICON_SIZE = G_defaults:readSetting("DGENERIC_ICON_SIZE")
local AUTHOR_SYMBOL = VirtualPath.AUTHOR_SYMBOL
local SERIES_SYMBOL = VirtualPath.SERIES_SYMBOL
local TAG_SYMBOL = VirtualPath.KEYWORD_SYMBOL

local function getMetadataLeafInfo(path)
    local base_dir, active_dimension, filter_state = VirtualPath.parse(path)
    if active_dimension then
        return
    end

    local leaf = VirtualPath.getLeafEntry(filter_state)
    if not leaf then
        return
    end

    local title = VirtualPath.displayValue(leaf.value)

    return {
        title = title,
        parent_path = VirtualPath.buildPreviousFilterPath(base_dir, filter_state),
    }
end

local function getVirtualBaseDir(file_manager)
    local path = file_manager.file_chooser and file_manager.file_chooser.path
    return VirtualPath.getVirtualBaseDir(path)
end

local function openBooks(file_manager)
    local base_dir = getVirtualBaseDir(file_manager)
    if base_dir and file_manager.file_chooser then
        file_manager.file_chooser:changeToPath(base_dir)
    else
        file_manager:onHome()
    end
end

local function browseByMetadata(file_manager, kind)
    if file_manager.onBrowseByMetadata then
        file_manager:onBrowseByMetadata(kind)
    end
end

local function getSelectedTabKey(file_manager)
    local path = file_manager and file_manager.file_chooser and file_manager.file_chooser.path
    local fragments = VirtualPath.getFragments(path)
    if not fragments then
        return "books"
    end

    for _, fragment in ipairs(fragments) do
        if fragment == AUTHOR_SYMBOL then
            return "authors"
        elseif fragment == SERIES_SYMBOL then
            return "series"
        elseif fragment == TAG_SYMBOL then
            return "tags"
        end
    end

    return "books"
end

local function getBackTitleBarInfo(file_manager)
    local path = file_manager and file_manager.file_chooser and file_manager.file_chooser.path
    local leaf_info = getMetadataLeafInfo(path)
    if not leaf_info then
        return
    end

    return {
        title = leaf_info.title,
        parent_path = leaf_info.parent_path,
        current_path = path,
    }
end

local ModeLeftContainer = LeftContainer:extend{
    visible_func = nil,
}

function ModeLeftContainer:isVisible()
    return self.visible_func == nil or self.visible_func()
end

function ModeLeftContainer:paintTo(bb, x, y)
    if self:isVisible() then
        return LeftContainer.paintTo(self, bb, x, y)
    end
end

function ModeLeftContainer:handleEvent(event)
    if self:isVisible() then
        return LeftContainer.handleEvent(self, event)
    end
    return false
end

local MetadataTabsTitleBar = OverlapGroup:extend{
    show_parent = nil,
    right_icon = nil,
    right_icon_tap_callback = function() end,
    right_icon_hold_callback = function() end,
}

function MetadataTabsTitleBar:init()
    self.show_parent = self.show_parent or self
    self.width = Screen:getWidth()
    self.icon_size = Screen:scaleBySize(DGENERIC_ICON_SIZE)
    self.button_padding = Screen:scaleBySize(5)
    self.tab_padding_h = Screen:scaleBySize(10)
    self.tab_padding_v = Screen:scaleBySize(5)
    self.tab_font_face = "smallinfofont"
    self.tab_font_size = 18
    self.status_padding_h = Screen:scaleBySize(7)
    self.status_gap = self.tab_padding_h
    self.titlebar_height = self.icon_size + self.button_padding * 2

    self.file_manager = self.file_manager or FileManager.instance
    local file_manager = self.file_manager
    local function getTabWidth(text)
        local face = Font:getFace(self.tab_font_face, self.tab_font_size)
        local normal_widget = TextWidget:new{
            text = text,
            face = face,
            bold = false,
        }
        local bold_widget = TextWidget:new{
            text = text,
            face = face,
            bold = true,
        }
        local width = math.max(normal_widget:getSize().w, bold_widget:getSize().w) + 2 * self.tab_padding_h
        normal_widget:free()
        bold_widget:free()
        return width
    end
    local function makeTab(key, text, callback, hold_callback)
        local tab_width = getTabWidth(text)
        local button = Button:new{
            text = text,
            text_font_face = self.tab_font_face,
            text_font_size = self.tab_font_size,
            text_font_bold = false,
            width = tab_width,
            bordersize = 0,
            padding_h = self.tab_padding_h,
            padding_v = self.tab_padding_v,
            callback = callback,
            hold_callback = hold_callback,
            show_parent = self.show_parent,
        }
        local tab = VerticalGroup:new{
            align = "center",
            button,
        }
        tab.key = key
        tab.button = button
        return tab
    end

    self.books_tab = makeTab("books", _("Books"), function()
        openBooks(file_manager)
    end, function()
        file_manager:onShowFolderMenu()
    end)
    self.series_tab = makeTab("series", _("Series"), function()
        browseByMetadata(file_manager, "series")
    end)
    self.authors_tab = makeTab("authors", _("Authors"), function()
        browseByMetadata(file_manager, "author")
    end)
    self.tags_tab = makeTab("tags", _("Tags"), function()
        browseByMetadata(file_manager, "tags")
    end)
    self.books_button = self.books_tab.button
    self.series_button = self.series_tab.button
    self.authors_button = self.authors_tab.button
    self.tags_button = self.tags_tab.button
    self.tab_label_height = self.books_button.label_container.dimen.h
    self.back_chevron_hit_width = self.tab_label_height + self.tab_padding_h
    self.tabs_group = HorizontalGroup:new{
        align = "bottom",
        allow_mirroring = false,
        self.books_tab,
        self.series_tab,
        self.authors_tab,
        self.tags_tab,
    }
    local tabs_size = self.tabs_group:getSize()
    self.titlebar_height = math.max(self.titlebar_height, tabs_size.h)
    local titlebar_body_height = self.titlebar_height
    self.dimen = Geom:new{
        x = 0,
        y = 0,
        w = self.width,
        h = titlebar_body_height,
    }

    self.tabs_stack = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = titlebar_body_height - tabs_size.h },
        self.tabs_group,
    }
    self.tabs_container = ModeLeftContainer:new{
        allow_mirroring = false,
        dimen = Geom:new{
            x = 0,
            y = 0,
            w = self.width,
            h = titlebar_body_height,
        },
        visible_func = function()
            return self.back_title_info == nil
        end,
        self.tabs_stack,
    }
    table.insert(self, self.tabs_container)
    self:updateSelectedTab(false)

    local status_widths = StatusIndicators.getWidths(self.tab_font_face, self.tab_font_size, self.status_padding_h)
    self.night_mode_width = status_widths.night_mode
    self.frontlight_width = status_widths.frontlight
    self.wifi_width = status_widths.wifi
    self.battery_width = status_widths.battery
    self.status_width = self.night_mode_width + self.frontlight_width + self.wifi_width + self.battery_width + 3 * self.status_gap
    self.night_mode_button = Button:new{
        text = StatusIndicators.NIGHT_MODE_SYMBOL,
        text_font_face = self.tab_font_face,
        text_font_size = self.tab_font_size,
        text_font_bold = false,
        width = self.night_mode_width,
        height = self.tab_label_height,
        bordersize = 0,
        padding_h = self.status_padding_h,
        padding_v = self.tab_padding_v,
        callback = function()
            UIManager:broadcastEvent(Event:new("ToggleNightMode"))
        end,
        show_parent = self.show_parent,
    }
    self.frontlight_button = Button:new{
        text = StatusIndicators.getFrontlightText(),
        text_font_face = self.tab_font_face,
        text_font_size = self.tab_font_size,
        text_font_bold = false,
        width = self.frontlight_width,
        height = self.tab_label_height,
        bordersize = 0,
        padding_h = self.status_padding_h,
        padding_v = self.tab_padding_v,
        callback = function()
            if Device:hasFrontlight() then
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end
        end,
        hold_callback = function()
            if Device:hasFrontlight() then
                UIManager:broadcastEvent(Event:new("ToggleFrontlight"))
                self:refreshStatusIndicators()
            end
        end,
        show_parent = self.show_parent,
    }
    self.wifi_button = Button:new{
        text = StatusIndicators.getWifiText(),
        text_font_face = self.tab_font_face,
        text_font_size = self.tab_font_size,
        text_font_bold = false,
        width = self.wifi_width,
        height = self.tab_label_height,
        bordersize = 0,
        padding_h = self.status_padding_h,
        padding_v = self.tab_padding_v,
        callback = function()
            StatusIndicators.toggleWifi(function()
                self:updateStatusIndicators()
            end)
        end,
        hold_callback = function()
            StatusIndicators.showWifiNetworks(function()
                self:updateStatusIndicators()
            end)
        end,
        show_parent = self.show_parent,
    }
    self.battery_button = Button:new{
        text = StatusIndicators.getBatteryText(),
        text_font_face = self.tab_font_face,
        text_font_size = self.tab_font_size,
        text_font_bold = false,
        width = self.battery_width,
        height = self.tab_label_height,
        bordersize = 0,
        padding_h = self.status_padding_h,
        padding_v = self.tab_padding_v,
        hold_callback = function()
            StatusIndicators.showBatteryInfo()
            self:updateStatusIndicators()
        end,
        show_parent = self.show_parent,
    }
    local status_row_items = {
        align = "bottom",
        allow_mirroring = false,
    }
    table.insert(status_row_items, self.night_mode_button)
    table.insert(status_row_items, HorizontalSpan:new{ width = self.status_gap })
    table.insert(status_row_items, self.frontlight_button)
    table.insert(status_row_items, HorizontalSpan:new{ width = self.status_gap })
    table.insert(status_row_items, self.wifi_button)
    table.insert(status_row_items, HorizontalSpan:new{ width = self.status_gap })
    table.insert(status_row_items, self.battery_button)
    self.status_row = HorizontalGroup:new(status_row_items)
    self.status_group = VerticalGroup:new{
        align = "right",
        self.status_row,
    }
    self.status_stack = VerticalGroup:new{
        align = "right",
        VerticalSpan:new{ width = math.max(0, titlebar_body_height - self.status_group:getSize().h) },
        self.status_group,
    }
    self.status_container = RightContainer:new{
        allow_mirroring = false,
        dimen = Geom:new{
            x = 0,
            y = 0,
            w = self.width,
            h = titlebar_body_height,
        },
        self.status_stack,
    }
    table.insert(self, self.status_container)

    self.back_title_width = self.width - self.status_width - self.tab_padding_h
    self.back_button = Button:new{
        text = "",
        align = "left",
        text_font_face = self.tab_font_face,
        text_font_size = self.tab_font_size,
        text_font_bold = true,
        avoid_text_truncation = false,
        width = self.back_title_width,
        height = self.tab_label_height,
        bordersize = 0,
        padding_h = 0,
        padding_v = self.tab_padding_v,
        callback = function()
            MetadataFacetDropdown.show(file_manager, function()
                return self:getDropdownAnchor()
            end)
        end,
        show_parent = self.show_parent,
    }
    self.back_chevron_button = Button:new{
        icon = "chevron.left",
        align = "left",
        icon_width = self.tab_label_height,
        icon_height = self.tab_label_height,
        width = self.back_chevron_hit_width,
        height = self.tab_label_height,
        bordersize = 0,
        padding_h = 0,
        padding_v = self.tab_padding_v,
        callback = function()
            self:onBackTitleTap()
        end,
        show_parent = self.show_parent,
    }
    self.back_button.width = self.back_title_width - self.back_chevron_button:getSize().w
    self.back_button:init()
    self.back_row = HorizontalGroup:new{
        align = "bottom",
        allow_mirroring = false,
        self.back_chevron_button,
        self.back_button,
    }
    self.back_title_group = VerticalGroup:new{
        align = "left",
        self.back_row,
    }
    self.back_stack = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = math.max(0, titlebar_body_height - self.back_title_group:getSize().h) },
        self.back_title_group,
    }
    self.back_container = ModeLeftContainer:new{
        allow_mirroring = false,
        dimen = Geom:new{
            x = 0,
            y = 0,
            w = self.width,
            h = titlebar_body_height,
        },
        visible_func = function()
            return self.back_title_info ~= nil
        end,
        self.back_stack,
    }
    table.insert(self, self.back_container)
    self:updateBackTitle(false)

    self.dimen.h = self.titlebar_height

    -- Compatibility for callers that anchor popups on title_bar.left_button.image.dimen.
    self.left_button = {
        image = {
            dimen = self.books_button[1].dimen or self.books_button.dimen,
        },
    }

    OverlapGroup.init(self)
end

function MetadataTabsTitleBar:updateBackTitle(refresh)
    local file_manager = self.file_manager or FileManager.instance
    local back_title_info = getBackTitleBarInfo(file_manager)
    local title = back_title_info and back_title_info.title or nil
    if self.back_title == title then
        return
    end

    self.back_title_info = back_title_info
    self.back_title = title
    self.back_button:setText(title and title .. " \u{25be}" or "", self.back_button.width)

    if refresh ~= false then
        UIManager:setDirty(self.show_parent, "ui", self.dimen)
    end
end

function MetadataTabsTitleBar:onBackTitleTap()
    local file_manager = self.file_manager or FileManager.instance
    local file_chooser = file_manager and file_manager.file_chooser
    local back_title_info = getBackTitleBarInfo(file_manager)
    if file_chooser and back_title_info then
        file_chooser:changeToPath(back_title_info.parent_path, back_title_info.current_path)
    end
end

function MetadataTabsTitleBar:getDropdownAnchor()
    local button = self.back_button
    return button and button[1] and button[1].dimen or button and button.dimen, true
end

function MetadataTabsTitleBar:updateStatusIndicators(refresh)
    if not self.battery_button then
        return
    end

    local battery_text = StatusIndicators.getBatteryText()
    local wifi_text = StatusIndicators.getWifiText()
    local frontlight_text = StatusIndicators.getFrontlightText()
    if self.battery_text == battery_text
            and self.wifi_text == wifi_text
            and self.frontlight_text == frontlight_text then
        return
    end

    self.battery_text = battery_text
    self.wifi_text = wifi_text
    self.frontlight_text = frontlight_text
    self.battery_button:setText(battery_text, self.battery_width)
    self.wifi_button:setText(wifi_text, self.wifi_width)
    self.frontlight_button:setText(frontlight_text, self.frontlight_width)
    if refresh ~= false then
        UIManager:setDirty(self.show_parent, "ui", self.dimen)
    end
end

function MetadataTabsTitleBar:refreshStatusIndicators()
    self:updateStatusIndicators(false)
    UIManager:setDirty(self.show_parent, "ui", self.dimen)
end

function MetadataTabsTitleBar:setTabSelected(tab, selected)
    if tab.button.text_font_bold ~= selected then
        tab.button.text_font_bold = selected
        tab.button.label_widget:free()
        tab.button:init()
    end
end

function MetadataTabsTitleBar:updateSelectedTab(refresh)
    local file_manager = self.file_manager or FileManager.instance
    local selected_tab_key = getSelectedTabKey(file_manager)
    if selected_tab_key == self.selected_tab_key then
        return
    end

    self.selected_tab_key = selected_tab_key
    for _, tab in ipairs({ self.books_tab, self.series_tab, self.authors_tab, self.tags_tab }) do
        self:setTabSelected(tab, tab.key == selected_tab_key)
    end

    if refresh ~= false then
        UIManager:setDirty(self.show_parent, "ui", self.dimen)
    end
end

function MetadataTabsTitleBar:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    self:updateBackTitle(false)
    self:updateSelectedTab(false)
    self:updateStatusIndicators(false)
    OverlapGroup.paintTo(self, bb, x, y)
    if self.books_button and self.books_button[1] and self.books_button[1].dimen then
        self.left_button.image.dimen = self.books_button[1].dimen
    end
end

function MetadataTabsTitleBar:getHeight()
    return self.titlebar_height
end

function MetadataTabsTitleBar:setTitle()
end

function MetadataTabsTitleBar:setSubTitle()
    self:updateBackTitle()
    self:updateSelectedTab()
    self:updateStatusIndicators()
end

function MetadataTabsTitleBar:setLeftIcon()
end

function MetadataTabsTitleBar:setRightIcon()
    self:updateStatusIndicators()
end

function MetadataTabsTitleBar:onNetworkConnected()
    NetworkMgr:queryNetworkState()
    self:updateStatusIndicators()
end

function MetadataTabsTitleBar:onNetworkDisconnected()
    NetworkMgr:queryNetworkState()
    self:updateStatusIndicators()
end

function MetadataTabsTitleBar:onNetworkDisconnecting()
    NetworkMgr.is_wifi_on = false
    self:updateStatusIndicators()
end

function MetadataTabsTitleBar:onFrontlightStateChanged()
    self:refreshStatusIndicators()
    UIManager:scheduleIn(0.2, self.refreshStatusIndicators, self)
    UIManager:scheduleIn(1, self.refreshStatusIndicators, self)
end

function MetadataTabsTitleBar:generateHorizontalLayout()
    local row = {
        self.back_button,
        self.books_button,
        self.series_button,
        self.authors_button,
        self.tags_button,
    }
    table.insert(row, self.night_mode_button)
    table.insert(row, self.frontlight_button)
    table.insert(row, self.wifi_button)
    table.insert(row, self.battery_button)
    return {
        row,
    }
end

function MetadataTabsTitleBar:generateVerticalLayout()
    local layout = {
        { self.back_button },
        { self.books_button },
        { self.series_button },
        { self.authors_button },
        { self.tags_button },
    }
    table.insert(layout, { self.night_mode_button })
    table.insert(layout, { self.frontlight_button })
    table.insert(layout, { self.wifi_button })
    table.insert(layout, { self.battery_button })
    return layout
end

local function findTitleBarUpvalue(func, seen)
    if type(func) ~= "function" then
        return
    end
    seen = seen or {}
    if seen[func] then
        return
    end
    seen[func] = true

    local nested = {}
    local idx = 1
    while true do
        local name, value = debug.getupvalue(func, idx)
        if not name then
            break
        end
        if name == "TitleBar" then
            return func, idx, value
        elseif type(value) == "function" then
            table.insert(nested, value)
        end
        idx = idx + 1
    end

    for _, nested_func in ipairs(nested) do
        local target_func, target_idx, original = findTitleBarUpvalue(nested_func, seen)
        if target_func then
            return target_func, target_idx, original
        end
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", function()
    local BookInfoManager = require("bookinfomanager")
    local FFIUtil = require("ffi/util")
    local FileChooser__updateItemsBuildUI = FileChooser._updateItemsBuildUI
    if not FileChooser__updateItemsBuildUI then
        return
    end

    local LOADING_TOAST_DELAY_S = 0.25

    local function maybeShowLoadingToast(state)
        if state.info then
            return
        end
        if FFIUtil.getTimestamp() - state.started_at < LOADING_TOAST_DELAY_S then
            return
        end
        state.info = InfoMessage:new{
            text = _("Loading covers…"),
            dismissable = false,
            flush_events_on_show = true,
        }
        UIManager:show(state.info)
        UIManager:forceRePaint()
    end

    local function closeLoadingToast(state)
        if state.info then
            UIManager:close(state.info)
            state.info = nil
        end
    end

    local function needsCoverExtraction(filepath, cover_specs)
        local bookinfo = BookInfoManager:getBookInfo(filepath, false)
        if not bookinfo then
            return true
        end
        if bookinfo.ignore_cover then
            return false
        end
        if not bookinfo.cover_fetched then
            return true
        end
        return bookinfo.has_cover and BookInfoManager.isCachedCoverInvalid(bookinfo, cover_specs)
    end

    local function extractVisibleLeafCovers(file_chooser)
        if not getMetadataLeafInfo(file_chooser.path) then
            return
        end
        if not file_chooser._do_cover_images or not file_chooser.item_width or not file_chooser.item_height then
            return
        end

        local cover_specs = {
            max_cover_w = file_chooser.item_width - 2 * Size.border.thin,
            max_cover_h = file_chooser.item_height - 2 * Size.border.thin,
        }
        local loading_state = {
            started_at = FFIUtil.getTimestamp(),
            info = nil,
        }
        local idx_offset = (file_chooser.page - 1) * file_chooser.perpage
        for idx = 1, file_chooser.perpage do
            local item = file_chooser.item_table[idx_offset + idx]
            if not item then
                break
            end
            if item.is_file and item.path and needsCoverExtraction(item.path, cover_specs) then
                maybeShowLoadingToast(loading_state)
                BookInfoManager:extractBookInfo(item.path, cover_specs)
            end
        end
        closeLoadingToast(loading_state)
    end

    FileChooser._updateItemsBuildUI = function(self, ...)
        local leaf_info = getMetadataLeafInfo(self.path)
        if leaf_info then
            extractVisibleLeafCovers(self)
        end
        return FileChooser__updateItemsBuildUI(self, ...)
    end
end)

local FileManager_setupLayout = FileManager.setupLayout
FileManager.setupLayout = function(self, ...)
    local target_func, titlebar_idx, original_titlebar = findTitleBarUpvalue(FileManager_setupLayout)
    if target_func and titlebar_idx then
        MetadataTabsTitleBar.file_manager = self
        debug.setupvalue(target_func, titlebar_idx, MetadataTabsTitleBar)
        local ok, ret = pcall(FileManager_setupLayout, self, ...)
        debug.setupvalue(target_func, titlebar_idx, original_titlebar)
        MetadataTabsTitleBar.file_manager = nil
        if not ok then
            error(ret)
        end
        return ret
    end
    return FileManager_setupLayout(self, ...)
end
