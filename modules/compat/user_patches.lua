-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local UserPatches = {}

local NOTICE_SETTING = "plainui_redundant_user_patches_notice_shown"
local OWNED_PATCHES = {
    "2-author-series.lua",
    "2-filemanager-metadata-tabs.lua",
    "2-finished-badge.lua",
    "2-reading-percentage.lua",
    "2-reading-stats-popup.lua",
}

local active_by_filename

local function defaultPatchesDir()
    local DataStorage = require("datastorage")
    return DataStorage:getDataDir() .. "/patches"
end

local function defaultFileExists(path)
    local lfs = require("libs/libkoreader-lfs")
    return lfs.attributes(path, "mode") == "file"
end

local function addDetected(detected, seen, filename)
    if not seen[filename] then
        seen[filename] = true
        table.insert(detected, filename)
    end
end

function UserPatches.detect(options)
    options = options or {}
    local patches_dir = options.patches_dir or defaultPatchesDir()
    local file_exists = options.file_exists or defaultFileExists
    local detected = {}
    local seen = {}

    for _, filename in ipairs(OWNED_PATCHES) do
        if file_exists(patches_dir .. "/" .. filename) then
            addDetected(detected, seen, filename)
        end
    end

    -- Older patch releases did not consistently expose version markers. These
    -- two handlers are unique enough to identify their source without guessing.
    local reader_ui = options.reader_ui
    if reader_ui and (reader_ui.reading_stats_popup_patch_version ~= nil
            or reader_ui.reading_stats_popup_api_version ~= nil
            or type(reader_ui.onShowReadingStatsPopup) == "function") then
        addDetected(detected, seen, "2-reading-stats-popup.lua")
    end
    local file_manager = options.file_manager
    if file_manager and type(file_manager.onBrowseByMetadata) == "function" then
        addDetected(detected, seen, "2-author-series.lua")
    end

    return detected
end

function UserPatches.initialize(options)
    if active_by_filename then
        return active_by_filename
    end
    options = options or {}
    local detected = UserPatches.detect(options)
    active_by_filename = {}
    for _, filename in ipairs(detected) do
        active_by_filename[filename] = true
    end
    return active_by_filename
end

function UserPatches.isActive(filename)
    return UserPatches.initialize()[filename] == true
end

function UserPatches.getActiveFilenames()
    local active = UserPatches.initialize()
    local filenames = {}
    for _, filename in ipairs(OWNED_PATCHES) do
        if active[filename] then
            table.insert(filenames, filename)
        end
    end
    return filenames
end

function UserPatches.showMigrationNotice()
    local filenames = UserPatches.getActiveFilenames()
    if #filenames == 0 or not G_reader_settings then
        return false
    end
    if G_reader_settings.isTrue and G_reader_settings:isTrue(NOTICE_SETTING) then
        return false
    end

    local Notification = require("ui/widget/notification")
    local UIManager = require("ui/uimanager")
    UIManager:show(Notification:new{
        text = "Plain UI detected redundant user patches: "
            .. table.concat(filenames, ", ")
            .. ". Remove these exact files from the patches folder and restart KOReader to use Plain UI's built-in implementations.",
        timeout = 8,
    })
    if G_reader_settings.saveSetting then
        G_reader_settings:saveSetting(NOTICE_SETTING, true)
        if G_reader_settings.flush then
            G_reader_settings:flush()
        end
    end
    return true
end

UserPatches.NOTICE_SETTING = NOTICE_SETTING
UserPatches.OWNED_PATCHES = OWNED_PATCHES
UserPatches._test = {
    reset = function()
        active_by_filename = nil
    end,
}

return UserPatches
