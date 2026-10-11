-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local Geom = require("ui/geometry")
local NetworkMgr = require("ui/network/manager")
local Screen = require("device").screen
local Size = require("ui/size")
local StatusIndicators = require("modules.shared.status_indicators")
local ToolbarStyle = require("modules.shared.toolbar_style")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local WifiMenu = ButtonDialog:extend{
    name = "plainui_wifi_menu",
    buttons = {}, info_padding = 0, info_margin = 0,
}
local active

function WifiMenu:init()
    self.width = math.min(Screen:scaleBySize(260), Screen:getWidth() - 2 * ToolbarStyle.padding)
    local anchor = self.anchor_rect
    if anchor then
        local point = Geom:new{
            x = math.max(ToolbarStyle.padding, math.min(anchor.x, Screen:getWidth() - self.width - ToolbarStyle.padding)),
            y = anchor.y + anchor.h + Screen:scaleBySize(4), w = 0, h = 0,
        }
        self.anchor = function() return point, true end
    end
    NetworkMgr:queryNetworkState()
    self.enable_wifi = NetworkMgr.is_wifi_on ~= true
    if self.refresh_callback then self.refresh_callback() end
    local width = self.width - 2 * Size.border.window - 2 * Size.padding.button
    local function button(text, action)
        return Button:new{
            text = text, align = "left", width = width, height = ToolbarStyle.button_height,
            bordersize = 0, padding_h = Screen:scaleBySize(16), padding_v = 0,
            text_font_face = "smallinfofont", text_font_size = 18, text_font_bold = false,
            show_parent = self,
            callback = function()
                UIManager:close(self)
                action()
            end,
        }
    end
    self.power_button = button(self.enable_wifi and _("Turn Wi-Fi on") or _("Turn Wi-Fi off"), function()
        StatusIndicators.setWifiEnabled(self.enable_wifi, self.refresh_callback)
    end)
    self.network_button = button(_("Choose network"), function()
        StatusIndicators.showWifiNetworks(self.refresh_callback)
    end)
    self._added_widgets = { self.power_button, self.network_button }
    ButtonDialog.init(self)
    self.layout = { { self.power_button }, { self.network_button } }
end

function WifiMenu:onCloseWidget()
    if active == self then active = nil end
    ButtonDialog.onCloseWidget(self)
end

function WifiMenu.show(anchor, refresh_callback)
    if active then UIManager:close(active); return end
    active = WifiMenu:new{ anchor_rect = anchor, refresh_callback = refresh_callback }
    UIManager:show(active)
    return active
end

return WifiMenu
