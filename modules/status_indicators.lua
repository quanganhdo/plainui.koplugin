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
StatusIndicators.WIFI_ON_SYMBOL = ""
StatusIndicators.WIFI_OFF_SYMBOL = ""

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

function StatusIndicators.getBatteryText()
    if not Device:hasBattery() then
        return ""
    end

    local powerd = Device:getPowerDevice()
    local batt_lvl = powerd:getCapacity()
    if Device:hasAuxBattery() and powerd:isAuxBatteryConnected() then
        batt_lvl = batt_lvl + powerd:getAuxCapacity()
        return powerd:getBatterySymbol(powerd:isAuxCharged(), powerd:isAuxCharging(), batt_lvl / 2)
    end
    return powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
end

function StatusIndicators.getWifiText()
    if not Device:hasWifiToggle() then
        return ""
    end
    if NetworkMgr.is_wifi_on == nil then
        NetworkMgr:queryNetworkState()
    end
    if NetworkMgr.is_wifi_on then
        return StatusIndicators.WIFI_ON_SYMBOL
    end
    return StatusIndicators.WIFI_OFF_SYMBOL
end

function StatusIndicators.getFrontlightText()
    if Device:hasFrontlight() then
        local powerd = Device:getPowerDevice()
        return powerd:isFrontlightOn() and StatusIndicators.FRONTLIGHT_SYMBOL or StatusIndicators.FRONTLIGHT_OFF_SYMBOL
    end
    return ""
end

function StatusIndicators.getWidths(font_face, font_size, padding_h)
    local powerd = Device:getPowerDevice()
    local battery_candidates = {
        "",
    }
    if Device:hasBattery() then
        table.insert(battery_candidates, powerd:getBatterySymbol(true, false, 100))
        table.insert(battery_candidates, powerd:getBatterySymbol(false, true, 100))
        table.insert(battery_candidates, powerd:getBatterySymbol(false, false, 100))
    end

    local icon_width = measureTextWidth({
        StatusIndicators.NIGHT_MODE_SYMBOL,
        StatusIndicators.FRONTLIGHT_SYMBOL,
        StatusIndicators.FRONTLIGHT_OFF_SYMBOL,
        StatusIndicators.WIFI_ON_SYMBOL,
        StatusIndicators.WIFI_OFF_SYMBOL,
    }, font_face, font_size, padding_h)
    return {
        night_mode = icon_width,
        frontlight = icon_width,
        wifi = icon_width,
        battery = measureTextWidth(battery_candidates, font_face, font_size, padding_h),
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
        text = StatusIndicators.getBatteryText(),
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

return StatusIndicators
