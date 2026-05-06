-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local TabViewOptions = {}

local SETTINGS_KEY = "plainui_tab_view_options"

local DEFAULTS = {
    books = {
        filter = "legacy",
        sort = "legacy",
        exclude_folders = false,
    },
    authors = {
        filter = "all",
        folder_sort = "name",
    },
    series = {
        filter = "all",
        folder_sort = "name",
    },
    tags = {
        filter = "all",
        folder_sort = "name",
    },
}

local VALID = {
    books = {
        filter = {
            legacy = true,
            all = true,
            unread = true,
            reading = true,
            finished = true,
        },
        sort = {
            legacy = true,
            recent = true,
            title = true,
            progress = true,
        },
    },
    metadata = {
        filter = {
            all = true,
            unread = true,
            reading = true,
            finished = true,
        },
        folder_sort = {
            name = true,
            book_count = true,
        },
    },
}

local METADATA_TABS = {
    authors = true,
    series = true,
    tags = true,
}

local function copyTable(value)
    local copy = {}
    for k, v in pairs(value or {}) do
        if type(v) == "table" then
            copy[k] = copyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function readSettings()
    if G_reader_settings and G_reader_settings.readSetting then
        local options = G_reader_settings:readSetting(SETTINGS_KEY)
        if type(options) == "table" then
            return options
        end
    end
    return {}
end

local function writeSettings(options)
    if G_reader_settings and G_reader_settings.saveSetting then
        G_reader_settings:saveSetting(SETTINGS_KEY, options)
        return true
    end
    return false
end

local function normalizeTabKey(tab_key)
    if tab_key == "keywords" then
        return "tags"
    end
    if DEFAULTS[tab_key] then
        return tab_key
    end
    return "books"
end

local function normalizeBooksOptions(options)
    local defaults = DEFAULTS.books
    options = type(options) == "table" and options or {}
    return {
        filter = VALID.books.filter[options.filter] and options.filter or defaults.filter,
        sort = VALID.books.sort[options.sort] and options.sort or defaults.sort,
        exclude_folders = options.exclude_folders == true,
    }
end

local function normalizeMetadataOptions(tab_key, options)
    local defaults = DEFAULTS[tab_key]
    options = type(options) == "table" and options or {}
    return {
        filter = VALID.metadata.filter[options.filter] and options.filter or defaults.filter,
        folder_sort = VALID.metadata.folder_sort[options.folder_sort]
            and options.folder_sort
            or defaults.folder_sort,
    }
end

function TabViewOptions.get(tab_key)
    tab_key = normalizeTabKey(tab_key)
    local settings = readSettings()
    if tab_key == "books" then
        return normalizeBooksOptions(settings.books)
    end
    return normalizeMetadataOptions(tab_key, settings[tab_key])
end

function TabViewOptions.getAll()
    local settings = readSettings()
    return {
        books = normalizeBooksOptions(settings.books),
        authors = normalizeMetadataOptions("authors", settings.authors),
        series = normalizeMetadataOptions("series", settings.series),
        tags = normalizeMetadataOptions("tags", settings.tags),
    }
end

function TabViewOptions.set(tab_key, field, value)
    tab_key = normalizeTabKey(tab_key)
    local settings = readSettings()
    local current = TabViewOptions.getAll()

    if tab_key == "books" then
        if field == "filter" and VALID.books.filter[value] then
            current.books.filter = value
        elseif field == "sort" and VALID.books.sort[value] then
            current.books.sort = value
        elseif field == "exclude_folders" then
            current.books.exclude_folders = value == true
        else
            return false
        end
    elseif METADATA_TABS[tab_key] then
        if field == "filter" and VALID.metadata.filter[value] then
            current[tab_key].filter = value
        elseif field == "folder_sort" and VALID.metadata.folder_sort[value] then
            current[tab_key].folder_sort = value
        else
            return false
        end
    else
        return false
    end

    settings.books = current.books
    settings.authors = current.authors
    settings.series = current.series
    settings.tags = current.tags
    return writeSettings(settings)
end

function TabViewOptions.isMetadataTab(tab_key)
    return METADATA_TABS[normalizeTabKey(tab_key)] or false
end

function TabViewOptions.getMetadataOptions(tab_key)
    tab_key = normalizeTabKey(tab_key)
    if not METADATA_TABS[tab_key] then
        return normalizeMetadataOptions("authors")
    end
    return TabViewOptions.get(tab_key)
end

TabViewOptions.DEFAULTS = copyTable(DEFAULTS)
TabViewOptions.SETTINGS_KEY = SETTINGS_KEY
TabViewOptions._test = {
    normalizeTabKey = normalizeTabKey,
}

return TabViewOptions
