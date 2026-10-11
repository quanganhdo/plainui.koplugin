-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Screen = Device.screen
local Size = require("ui/size")
local StatusIcon = require("modules.shared.status_icon")
local StatusIndicators = require("modules.shared.status_indicators")
local TextWidget = require("ui/widget/textwidget")
local ToolbarStyle = require("modules.shared.toolbar_style")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local datetime = require("datetime")
local _ = require("gettext")

local FileIconButton = InputContainer:extend{
    enabled = true,
}

function FileIconButton:init()
    self.icon_widget = ImageWidget:new{
        alpha = false,
        dim = not self.enabled,
        file = self.icon_file,
        width = self.icon_width,
        height = self.icon_height,
        is_icon = true,
    }
    local icon_container = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height },
        self.icon_widget,
    }
    self.selection_frame = FrameContainer:new{
        width = self.width,
        height = self.height,
        bordersize = 0,
        padding = 0,
        background = Blitbuffer.COLOR_WHITE,
        invert = self.selected == true,
        icon_container,
    }
    self[1] = self.selection_frame
    self.dimen = self[1]:getSize()
    self.ges_events = {
        TapFileIconButton = {
            GestureRange:new{ ges = "tap", range = self.dimen },
        },
    }
    if self.hold_callback then
        self.ges_events.HoldFileIconButton = { GestureRange:new{ ges = "hold", range = self.dimen } }
        self.ges_events.HoldReleaseFileIconButton = { GestureRange:new{ ges = "hold_release", range = self.dimen } }
    end
end

function FileIconButton:setIcon(icon_file)
    if self.icon_file == icon_file then return false end
    self.icon_widget:free()
    self.icon_file = icon_file
    self.icon_widget.file = icon_file
    return true
end

function FileIconButton:setSelected(selected)
    selected = selected == true
    if (self.selected == true) == selected then
        self.selected = selected
        return false
    end
    self.selected = selected
    self.selection_frame.invert = selected
    return true
end

function FileIconButton:onTapFileIconButton()
    if self.enabled and self.callback then
        self.callback()
    end
    return true
end

function FileIconButton:onHoldFileIconButton()
    if self.enabled and self.hold_callback then
        self.hold_callback()
        self.hold_handled = true
        return true
    end
end

function FileIconButton:onHoldReleaseFileIconButton()
    if self.hold_handled then
        self.hold_handled = nil
        return true
    end
end

local DragChevron = Widget:extend{
    color = Blitbuffer.COLOR_DARK_GRAY,
}

function DragChevron:paintTo(bb, x, y)
    local half_width = math.floor(self.dimen.w / 2)
    local stroke = math.max(1, Size.line.medium)
    local drop = self.dimen.h - stroke
    for offset = 0, half_width - 1 do
        local y_offset = math.floor(offset * drop / half_width)
        bb:paintRect(x + offset, y + y_offset, 1, stroke, self.color)
        bb:paintRect(x + self.dimen.w - offset - 1, y + y_offset, 1, stroke, self.color)
    end
end

local ReaderOverlay = InputContainer:extend{
    covers_header = true,
    stop_events_propagation = true,
}

function ReaderOverlay:init()
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    local horizontal_padding = ToolbarStyle.padding
    local content_width = screen_width - 2 * horizontal_padding
    local status_height = Size.item.height_default
    local action_height = ToolbarStyle.button_height
    local status_padding_h = Screen:scaleBySize(7)
    local status_gap = Screen:scaleBySize(12)
    local wifi_icon_size = Screen:scaleBySize(20)
    local battery_icon_height = Screen:scaleBySize(20)
    local battery_icon_width = math.floor(battery_icon_height * 0.7 + 0.5)
    local battery_state = StatusIndicators.getCombinedBatteryState()
    local battery_percentage_text = StatusIndicators.getBatteryPercentageText()
    local wifi_state = StatusIndicators.getWifiState()
    local status_slot_width = wifi_icon_size + 2 * status_padding_h
    local back_text = "←  " .. _("File Manager")
    local back_text_widget = TextWidget:new{
        text = back_text,
        face = Font:getFace("cfont", 18),
    }
    local back_width = back_text_widget:getSize().w + Screen:scaleBySize(8)
    back_text_widget:free()

    self.dimen = Geom:new{
        x = 0,
        y = 0,
        w = screen_width,
        h = screen_height,
    }

    self.time_widget = TextWidget:new{
        text = self:getTimeText(),
        face = Font:getFace("smallinfofont", 16),
    }
    self.battery_widget = StatusIcon:new{
        icon_file = StatusIndicators.getBatteryIconPath(),
        icon_width = battery_icon_width,
        icon_height = battery_icon_height,
        visible = battery_state.available,
        width = battery_icon_width,
        height = status_height,
    }
    self.battery_percentage_widget = TextWidget:new{
        text = battery_percentage_text,
        face = Font:getFace("smallinfofont", 14),
    }
    self.wifi_widget = StatusIcon:new{
        icon_file = StatusIndicators.getWifiIconPath(),
        icon_width = wifi_icon_size,
        icon_height = wifi_icon_size,
        visible = wifi_state.available,
        width = status_slot_width,
        height = status_height,
    }
    self.battery_group = HorizontalGroup:new{
        allow_mirroring = false,
        self.battery_percentage_widget,
        HorizontalSpan:new{ width = Screen:scaleBySize(3) },
        self.battery_widget,
    }
    self.battery_slot = CenterContainer:new{
        dimen = Geom:new{ w = self.battery_group:getSize().w, h = status_height },
        self.battery_group,
    }
    self.status_right_group = HorizontalGroup:new{
        allow_mirroring = false,
        self.wifi_widget,
        HorizontalSpan:new{ width = status_gap },
        self.battery_slot,
    }

    self.status_row = OverlapGroup:new{
        allow_mirroring = false,
        dimen = Geom:new{ w = content_width, h = status_height },
        LeftContainer:new{
            dimen = Geom:new{ w = content_width, h = status_height },
            self.time_widget,
        },
        RightContainer:new{
            dimen = Geom:new{ w = content_width, h = status_height },
            self.status_right_group,
        },
        CenterContainer:new{
            dimen = Geom:new{ w = content_width, h = status_height },
            ignore = "height",
            VerticalGroup:new{
                VerticalSpan:new{ width = Screen:scaleBySize(10) },
                DragChevron:new{
                    dimen = Geom:new{
                        w = Screen:scaleBySize(24),
                        h = Screen:scaleBySize(5),
                    },
                },
            },
        },
    }
    self.menu_hint_dimen = Geom:new{
        x = math.floor((screen_width - Screen:scaleBySize(120)) / 2),
        y = 0,
        w = Screen:scaleBySize(120),
        h = status_height,
    }
    self.status_refresh_dimen = Geom:new{
        x = 0,
        y = 0,
        w = screen_width,
        h = status_height,
    }

    local status_frame = FrameContainer:new{
        width = screen_width,
        height = status_height,
        bordersize = 0,
        padding = 0,
        padding_left = horizontal_padding,
        padding_right = horizontal_padding,
        background = Blitbuffer.COLOR_WHITE,
        self.status_row,
    }

    local back_button = Button:new{
        text = back_text,
        align = "left",
        width = back_width,
        height = action_height,
        bordersize = 0,
        padding_h = 0,
        text_font_face = "cfont",
        text_font_size = 18,
        callback = function()
            self.plugin:backToFileManager()
        end,
    }
    local action_button_width = ToolbarStyle.button_width
    local action_button_gap = ToolbarStyle.button_gap
    local action_icon_size = ToolbarStyle.icon_size
    local action_icon_dir = self.plugin.path .. "/icons/tabler/"
    if Device:hasFrontlight() then
        self.lighting_button = FileIconButton:new{
            action_id = "lighting",
            icon_file = StatusIndicators.getFrontlightIconPath(),
            width = action_button_width, height = action_height,
            icon_width = action_icon_size, icon_height = action_icon_size,
            callback = function()
                self.plugin:closeReadingStatsPopup()
                self.plugin:closeTypographyOverlay()
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end,
            hold_callback = function()
                UIManager:broadcastEvent(Event:new("ToggleFrontlight"))
                self:refreshDisplayControls()
            end,
        }
    end
    self.dark_mode_button = FileIconButton:new{
        action_id = "dark_mode",
        icon_file = StatusIndicators.getNightModeIconPath(),
        width = action_button_width, height = action_height,
        icon_width = action_icon_size, icon_height = action_icon_size,
        callback = function()
            UIManager:broadcastEvent(Event:new("ToggleNightMode"))
        end,
    }
    local typography_button = FileIconButton:new{
        action_id = "typography",
        icon_file = action_icon_dir .. "text-size.svg",
        width = action_button_width,
        height = action_height,
        icon_width = action_icon_size,
        icon_height = action_icon_size,
        enabled = self.plugin.ui.rolling ~= nil,
        callback = function()
            self.plugin:showTypographyOverlay()
        end,
    }
    if self.plugin:hasAnchoredReadingStatsPopup() then
        self.stats_button = FileIconButton:new{
            action_id = "stats",
            icon_file = action_icon_dir .. "chart-bar.svg",
            width = action_button_width,
            height = action_height,
            icon_width = action_icon_size,
            icon_height = action_icon_size,
            callback = function()
                self.plugin:showReadingStatsPopup(self.panel:getSize().h)
            end,
        }
    end
    self.toolbar_action_buttons = {}
    if self.lighting_button then table.insert(self.toolbar_action_buttons, self.lighting_button) end
    table.insert(self.toolbar_action_buttons, self.dark_mode_button)
    table.insert(self.toolbar_action_buttons, typography_button)
    self.more_button = FileIconButton:new{
        action_id = "more", icon_file = action_icon_dir .. "dots.svg",
        width = action_button_width, height = action_height,
        icon_width = action_icon_size, icon_height = action_icon_size,
        callback = function() self.plugin:showMoreMenu(self.more_button.dimen) end,
    }
    table.insert(self.toolbar_action_buttons, self.more_button)
    local action_control_children = {
        allow_mirroring = false,
    }
    for i, button in ipairs(self.toolbar_action_buttons) do
        if i > 1 then
            table.insert(action_control_children, HorizontalSpan:new{ width = action_button_gap })
        end
        table.insert(action_control_children, button)
    end
    local action_controls = HorizontalGroup:new(action_control_children)
    local action_spacer_width = math.max(
        0,
        content_width - back_width - action_controls:getSize().w
    )
    local action_row = HorizontalGroup:new{
        allow_mirroring = false,
        back_button,
        HorizontalSpan:new{ width = action_spacer_width },
        action_controls,
    }
    local row_height = action_row:getSize().h
    local action_frame = FrameContainer:new{
        width = screen_width,
        height = row_height,
        bordersize = 0,
        padding = 0,
        padding_left = horizontal_padding,
        padding_right = horizontal_padding,
        background = Blitbuffer.COLOR_WHITE,
        action_row,
    }

    local title_width = math.max(0, content_width
        - (self.stats_button and action_button_width + action_button_gap or 0))
    local ui = self.plugin.ui
    local props = ui.doc_props or {}
    local title = props.display_title or props.title
        or (ui.document and ui.document.file and ui.document.file:match("[^/]+$"))
        or _("Untitled book")
    self.book_title_widget = TextWidget:new{
        text = title:gsub("%s+", " "),
        face = Font:getFace("smallinfofont", 18),
        bold = true,
        max_width = title_width,
        truncate_with_ellipsis = true,
        truncate_left = false,
    }
    local title_children = {
        allow_mirroring = false,
        LeftContainer:new{
            dimen = Geom:new{ w = title_width, h = row_height },
            self.book_title_widget,
        },
    }
    if self.stats_button then
        table.insert(title_children, HorizontalSpan:new{ width = action_button_gap })
        table.insert(title_children, self.stats_button)
        -- Keep both rows available for popup switching and selection feedback.
        table.insert(self.toolbar_action_buttons, self.stats_button)
    end
    self.book_title_frame = FrameContainer:new{
        width = screen_width, height = row_height,
        bordersize = 0, padding = 0,
        padding_left = horizontal_padding, padding_right = horizontal_padding,
        background = Blitbuffer.COLOR_WHITE,
        HorizontalGroup:new(title_children),
    }

    self.panel = FrameContainer:new{
        width = screen_width,
        bordersize = 0,
        padding = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            status_frame,
            action_frame,
            LineWidget:new{
                background = Blitbuffer.COLOR_GRAY,
                dimen = Geom:new{ w = screen_width, h = Size.line.medium },
            },
            self.book_title_frame,
            LineWidget:new{
                background = Blitbuffer.COLOR_BLACK,
                dimen = Geom:new{ w = screen_width, h = Size.line.medium },
            },
        },
    }

    self[1] = TopContainer:new{
        dimen = self.dimen:copy(),
        self.panel,
    }

    self.ges_events = {
        TapClosePlainReader = {
            GestureRange:new{ ges = "tap", range = self.dimen },
        },
        SwipeClosePlainReader = {
            GestureRange:new{ ges = "swipe", range = self.dimen },
        },
        PanPlainReaderMenu = {
            GestureRange:new{ ges = "pan", range = self.dimen },
        },
    }

    self.menu_drag_enabled = false
    self.enable_menu_drag_callback = function()
        if self.plugin.overlay == self then
            self.menu_drag_enabled = true
        end
    end
    self.status_refresh_callback = function()
        if self.plugin.overlay ~= self then
            return
        end
        self:refreshStatus()
        self:scheduleStatusRefresh()
    end
end

function ReaderOverlay:getToolbarActionAt(pos)
    for _, button in ipairs(self.toolbar_action_buttons) do
        if button.dimen and pos:intersectWith(button.dimen) then
            return button
        end
    end
end

function ReaderOverlay:setSelectedAction(action_id, force_repaint)
    self.selected_action = action_id
    for _, button in ipairs(self.toolbar_action_buttons) do
        local changed = button:setSelected(button.action_id == action_id)
        if (changed or force_repaint) and button.dimen then
            local button_dimen = button.dimen
            UIManager:setDirty(self, function()
                return "ui", button_dimen
            end)
        end
    end
end

function ReaderOverlay:triggerToolbarAction(button)
    if button and button.enabled and button.callback then
        button.callback()
        return true
    end
    return false
end

function ReaderOverlay:getTimeText()
    return datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
end

function ReaderOverlay:refreshStatus()
    local battery_state = StatusIndicators.getCombinedBatteryState()
    local battery_percentage_text = StatusIndicators.getBatteryPercentageText()
    local wifi_state = StatusIndicators.getWifiState()
    self.time_widget:setText(self:getTimeText())
    self.battery_widget:setIcon(StatusIndicators.getBatteryIconPath(), battery_state.available)
    self.battery_percentage_widget:setText(battery_percentage_text)
    self.battery_group:resetLayout()
    self.battery_slot.dimen.w = self.battery_group:getSize().w
    self.wifi_widget:setIcon(StatusIndicators.getWifiIconPath(), wifi_state.available)
    self.status_right_group:resetLayout()
    self:refreshDisplayControls()
    UIManager:setDirty(self, function()
        return "ui", self.status_refresh_dimen
    end)
end

function ReaderOverlay:refreshDisplayControls()
    for _, control in ipairs{
        { self.dark_mode_button, StatusIndicators.getNightModeIconPath() },
        { self.lighting_button, StatusIndicators.getFrontlightIconPath() },
    } do
        local button, icon_file = control[1], control[2]
        if button and button:setIcon(icon_file) then
            UIManager:setDirty(self, "ui", button.dimen)
        end
    end
end

function ReaderOverlay:onToggleNightMode()
    -- The device listener changes screen mode during the same broadcast.
    UIManager:nextTick(function()
        if self.plugin.overlay == self then self:refreshDisplayControls() end
    end)
end

function ReaderOverlay:onSetNightMode()
    self:onToggleNightMode()
end

function ReaderOverlay:onFrontlightStateChanged()
    self:refreshDisplayControls()
end

function ReaderOverlay:scheduleStatusRefresh()
    local seconds = tonumber(os.date("%S")) or 0
    UIManager:scheduleIn(61 - seconds, self.status_refresh_callback)
end

function ReaderOverlay:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.panel.dimen
    end)
    UIManager:scheduleIn(0.25, self.enable_menu_drag_callback)
    self:scheduleStatusRefresh()
    return true
end

function ReaderOverlay:onCloseWidget()
    UIManager:unschedule(self.enable_menu_drag_callback)
    UIManager:unschedule(self.status_refresh_callback)
    if self.plugin.overlay == self then
        self.plugin.overlay = nil
    end
    UIManager:setDirty(nil, function()
        return "flashui", self.panel.dimen
    end)
end

function ReaderOverlay:onTapClosePlainReader(_, ges)
    if ges.pos:intersectWith(self.menu_hint_dimen) then
        self.plugin:showDefaultMenu()
        return true
    end
    if self.panel.dimen and ges.pos:notIntersectWith(self.panel.dimen) then
        self.plugin:closeOverlay()
    end
    return true
end

function ReaderOverlay:onSwipeClosePlainReader(_, ges)
    if ges.direction == "south" and self.menu_drag_enabled then
        self.plugin:showDefaultMenu()
        return true
    end
    if ges.direction == "north" then
        self.plugin:closeOverlay()
        return true
    end
    return true
end

function ReaderOverlay:onPanPlainReaderMenu(_, ges)
    if ges.direction == "south" and self.menu_drag_enabled then
        self.plugin:showDefaultMenu()
    end
    return true
end

function ReaderOverlay:onNetworkConnected()
    self:refreshStatus()
end

function ReaderOverlay:onNetworkDisconnected()
    self:refreshStatus()
end

function ReaderOverlay:onClose()
    self.plugin:closeOverlay()
    return true
end

return ReaderOverlay
