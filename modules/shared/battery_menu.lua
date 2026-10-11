-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Screen = require("device").screen
local Size = require("ui/size")
local StatusIndicators = require("modules.shared.status_indicators")
local TextWidget = require("ui/widget/textwidget")
local ToolbarStyle = require("modules.shared.toolbar_style")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local BatteryMenu = ButtonDialog:extend{
    name = "plainui_battery_menu",
    buttons = {}, info_padding = 0, info_margin = 0,
}
local active

function BatteryMenu:init()
    self.width = math.min(Screen:scaleBySize(260), Screen:getWidth() - 2 * ToolbarStyle.padding)
    local anchor = self.anchor_rect
    if anchor then
        local point = Geom:new{
            x = math.max(ToolbarStyle.padding, math.min(anchor.x, Screen:getWidth() - self.width - ToolbarStyle.padding)),
            y = anchor.y + anchor.h + Screen:scaleBySize(4), w = 0, h = 0,
        }
        self.anchor = function() return point, true end
    end
    local width = self.width - 2 * Size.border.window - 2 * Size.padding.button
    local inset = Screen:scaleBySize(16)
    self.heading = TextWidget:new{
        text = T(_("Battery %1"), StatusIndicators.getBatteryPercentageText()),
        face = Font:getFace("cfont", 18), bold = true, max_width = width - 2 * inset,
    }
    self._added_widgets = {
        FrameContainer:new{
            width = width, bordersize = 0, padding = 0, padding_left = inset,
            not_focusable = true,
            LeftContainer:new{
                dimen = Geom:new{ w = width - 2 * inset, h = Screen:scaleBySize(36) },
                self.heading,
            },
        },
    }
    if StatusIndicators.hasBatteryStatistics() then
        self._added_widgets[#self._added_widgets + 1] = LineWidget:new{
            background = Blitbuffer.COLOR_GRAY, dimen = Geom:new{ w = width, h = Size.line.medium },
            not_focusable = true,
        }
        self.stats_button = Button:new{
            text = _("View battery stats"), align = "left", width = width,
            height = ToolbarStyle.button_height, bordersize = 0,
            padding_h = inset, padding_v = 0,
            text_font_face = "smallinfofont", text_font_size = 18, text_font_bold = false,
            show_parent = self,
            callback = function()
                UIManager:close(self)
                StatusIndicators.showBatteryInfo()
            end,
        }
        self._added_widgets[#self._added_widgets + 1] = self.stats_button
    end
    ButtonDialog.init(self)
    self.layout = self.stats_button and { { self.stats_button } } or {}
end

function BatteryMenu:onCloseWidget()
    if active == self then active = nil end
    ButtonDialog.onCloseWidget(self)
end

function BatteryMenu.show(anchor)
    if active then UIManager:close(active); return end
    active = BatteryMenu:new{ anchor_rect = anchor }
    UIManager:show(active)
    return active
end

return BatteryMenu
