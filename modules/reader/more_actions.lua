-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Device = require("device")
local _ = require("gettext")

local Actions = {}

local function hasAction(object, name)
    local handler = object and object[name]
    if type(handler) == "function" then return true end
    -- KOReader wraps plugin event handlers in callable HandlerSandbox tables.
    local mt = type(handler) == "table" and getmetatable(handler)
    return type(mt) == "table" and type(mt.__call) == "function"
end

local function configured(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

function Actions.getTouchInstructions()
    local text = Device.isKindle and Device:isKindle()
        and _("Disable touchscreen?\n\nPut your Kindle to sleep, then wake it to restore touch.")
        or _("Disable touchscreen?\n\nPut your device to sleep, then wake it to restore touch.")
    local page_keys = { LPgBack = true, LPgFwd = true, RPgBack = true, RPgFwd = true }
    local event_map = Device.input and Device.input.event_map
    for _, key in pairs(event_map or {}) do
        if page_keys[key] then return text end
    end
    return text .. "\n\n" .. _("To keep turning pages, enable “Swipes always active” in Page turns.")
end

function Actions.getItems(ui)
    local groups = { {}, {}, {} }
    local function add(group, key, text, event, arg)
        groups[group][#groups[group] + 1] = { key = key, text = text, event = event, arg = arg }
    end
    if hasAction(ui.bookinfo, "onShowBookInfo") then
        add(1, "book_info", _("View book info"), "ShowBookInfo")
    end
    if hasAction(ui.bookinfo, "onShowBookCover") then
        add(1, "cover", _("View cover"), "ShowBookCover")
    end
    if hasAction(ui.dictionary, "onShowDictionaryLookup") then
        add(1, "dictionary", _("Look up a word"), "ShowDictionaryLookup")
    end
    local sync = ui.kosync
    local settings = sync and sync.settings
    if settings and configured(settings.username) and configured(settings.userkey) then
        if hasAction(sync, "onKOSyncPushProgress") then
            add(2, "upload_progress", _("Upload book progress"), "KOSyncPushProgress")
        end
        if hasAction(sync, "onKOSyncPullProgress") then
            add(2, "download_progress", _("Download book progress"), "KOSyncPullProgress")
        end
    end
    local stats = ui.statistics
    if hasAction(stats, "onSyncBookStats") and hasAction(stats, "canSync") and stats:canSync() then
        add(2, "sync_stats", _("Sync reading stats"), "SyncBookStats")
    end
    if Device:isTouchDevice() then
        add(3, "disable_touch", _("Disable touchscreen"), "IgnoreTouchInput", true)
    end
    local items = {}
    for _, group in ipairs(groups) do
        if #group > 0 then
            if #items > 0 then items[#items].separator = true end
            for _, item in ipairs(group) do items[#items + 1] = item end
        end
    end
    return items
end

return Actions
