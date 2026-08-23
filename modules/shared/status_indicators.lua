-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local PluginLoader = require("pluginloader")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")

local StatusIndicators = {}

StatusIndicators.NIGHT_MODE_SYMBOL = "◐"
StatusIndicators.FRONTLIGHT_SYMBOL = "☼"
StatusIndicators.FRONTLIGHT_OFF_SYMBOL = "☀"

local source = debug.getinfo(1, "S").source
local module_path = source:sub(1, 1) == "@" and source:sub(2) or source
local plugin_path = module_path:match("^(.*)/modules/shared/status_indicators%.lua$") or "."
local icons_path = plugin_path .. "/icons/tabler"

local function measureTextWidth(candidates, font_face, font_size, padding_h)
    local face = Font:getFace(font_face, font_size)
    local width = 0
    for _, text in ipairs(candidates) do
        local widget = TextWidget:new{
            text = text,
            face = face,
        }
        width = math.max(width, widget:getSize().w)
        widget:free()
    end
    return width + 2 * padding_h
end

function StatusIndicators.getIconPath(icon_name)
    return icons_path .. "/" .. icon_name .. ".svg"
end

function StatusIndicators.getNightModeIconName()
    return Device.screen.night_mode and "moon-filled" or "moon"
end

function StatusIndicators.getNightModeIconPath()
    return StatusIndicators.getIconPath(StatusIndicators.getNightModeIconName())
end

function StatusIndicators.getFrontlightState()
    local available = Device:hasFrontlight()
    return {
        available = available,
        enabled = available and Device:getPowerDevice():isFrontlightOn() == true,
    }
end

function StatusIndicators.getFrontlightIconName()
    return StatusIndicators.getFrontlightState().enabled and "bulb" or "bulb-off"
end

function StatusIndicators.getFrontlightIconPath()
    return StatusIndicators.getIconPath(StatusIndicators.getFrontlightIconName())
end

function StatusIndicators.getCombinedBatteryState()
    if not Device:hasBattery() then
        return {
            available = false,
            capacity = 0,
            charged = false,
            charging = false,
        }
    end

    local powerd = Device:getPowerDevice()
    local capacity = tonumber(powerd:getCapacity()) or 0
    local charged = powerd:isCharged() == true
    local charging = powerd:isCharging() == true
    if Device:hasAuxBattery() and powerd:isAuxBatteryConnected() then
        capacity = (capacity + (tonumber(powerd:getAuxCapacity()) or 0)) / 2
        charged = charged and powerd:isAuxCharged() == true
        charging = charging or powerd:isAuxCharging() == true
    end
    return {
        available = true,
        capacity = math.max(0, math.min(100, capacity)),
        charged = charged,
        charging = charging,
    }
end

local function getBatteryIconNameForState(state)
    if state.charged then
        return "battery-vertical-charged"
    end
    if state.charging then
        return "battery-vertical-charging"
    end
    if state.capacity >= 80 then
        return "battery-vertical-4"
    elseif state.capacity >= 60 then
        return "battery-vertical-3"
    elseif state.capacity >= 40 then
        return "battery-vertical-2"
    elseif state.capacity >= 20 then
        return "battery-vertical-1"
    end
    return "battery-vertical"
end

function StatusIndicators.getBatteryIconName()
    return getBatteryIconNameForState(StatusIndicators.getCombinedBatteryState())
end

function StatusIndicators.getBatteryIconPath()
    return StatusIndicators.getIconPath(StatusIndicators.getBatteryIconName())
end

function StatusIndicators.getBatteryPercentageText()
    local state = StatusIndicators.getCombinedBatteryState()
    if not state.available then
        return ""
    end
    return tostring(math.floor(state.capacity + 0.5)) .. "%"
end

function StatusIndicators.getWifiState()
    local available = Device:hasWifiToggle()
    if not available then
        return {
            available = false,
            enabled = false,
        }
    end
    if NetworkMgr.is_wifi_on == nil then
        NetworkMgr:queryNetworkState()
    end
    return {
        available = available,
        enabled = available and NetworkMgr.is_wifi_on == true,
    }
end

function StatusIndicators.getWifiIconName()
    return StatusIndicators.getWifiState().enabled and "wifi" or "wifi-off"
end

function StatusIndicators.getWifiIconPath()
    return StatusIndicators.getIconPath(StatusIndicators.getWifiIconName())
end

function StatusIndicators.getFrontlightText()
    if Device:hasFrontlight() then
        local powerd = Device:getPowerDevice()
        return powerd:isFrontlightOn() and StatusIndicators.FRONTLIGHT_SYMBOL or StatusIndicators.FRONTLIGHT_OFF_SYMBOL
    end
    return ""
end

function StatusIndicators.getWidths(font_face, font_size, padding_h, icon_widths)
    icon_widths = icon_widths or {}
    local legacy_icon_width = measureTextWidth({
        StatusIndicators.NIGHT_MODE_SYMBOL,
        StatusIndicators.FRONTLIGHT_SYMBOL,
        StatusIndicators.FRONTLIGHT_OFF_SYMBOL,
    }, font_face, font_size, padding_h)
    return {
        night_mode = icon_widths.night_mode
            and icon_widths.night_mode + 2 * padding_h or legacy_icon_width,
        frontlight = icon_widths.frontlight
            and icon_widths.frontlight + 2 * padding_h or legacy_icon_width,
        wifi = (icon_widths.wifi or 0) + 2 * padding_h,
        battery = (icon_widths.battery or 0) + 2 * padding_h,
    }
end

function StatusIndicators.showBatteryInfo()
    if not Device:hasBattery() then
        return
    end
    if PluginLoader.loaded_plugins and PluginLoader:isPluginLoaded("batterystat") then
        UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
        return
    end

    UIManager:show(InfoMessage:new{
        text = StatusIndicators.getBatteryPercentageText(),
    })
end

function StatusIndicators.toggleWifi(refresh_callback)
    if not Device:hasWifiToggle() then
        return
    end

    NetworkMgr:queryNetworkState()
    local complete_callback = function()
        NetworkMgr:queryNetworkState()
        if refresh_callback then
            refresh_callback()
        end
    end
    if NetworkMgr.is_wifi_on and NetworkMgr.is_connected then
        NetworkMgr:toggleWifiOff(complete_callback, true)
    elseif NetworkMgr.is_wifi_on then
        NetworkMgr:promptWifi(complete_callback, nil, true)
    else
        NetworkMgr:toggleWifiOn(complete_callback, nil, true)
    end
end

function StatusIndicators.showWifiNetworks(refresh_callback)
    if not Device:hasWifiToggle() then
        return
    end

    NetworkMgr:queryNetworkState()
    local complete_callback = function()
        NetworkMgr:queryNetworkState()
        if refresh_callback then
            refresh_callback()
        end
    end
    if NetworkMgr.is_wifi_on then
        NetworkMgr.wifi_toggle_long_press = true
        NetworkMgr:reconnectOrShowNetworkMenu(complete_callback, true)
    else
        NetworkMgr:toggleWifiOn(complete_callback, true, true)
    end
end

StatusIndicators._test = {
    getBatteryIconNameForState = getBatteryIconNameForState,
}

return StatusIndicators
