-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ffiUtil = require("ffi/util")
local DocumentRegistry = require("document/documentregistry")
local FilterState = require("modules.filter_state")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local T = ffiUtil.template

local MetadataSource = {}
local matching_files_cache = {}
local facet_values_cache = {}
local status_counts_cache = {}
local file_validity_cache = {}

local BOOK_EXTENSIONS = {
    azw = true,
    cbr = true,
    cbt = true,
    cbz = true,
    djv = true,
    djvu = true,
    epub = true,
    epub3 = true,
    fb2 = true,
    ["fb2.zip"] = true,
    fb3 = true,
    mobi = true,
    pdf = true,
    rtf = true,
    ["rtf.zip"] = true,
}

local MULTIPART_BOOK_EXTENSIONS = {
    "fb2.zip",
    "rtf.zip",
}

local STATUS_BY_FILTER = {
    unread = "new",
    reading = "reading",
    finished = "complete",
}

local function getBookExtension(filepath)
    if not filepath then
        return
    end

    local lower_filepath = filepath:lower()
    for _, extension in ipairs(MULTIPART_BOOK_EXTENSIONS) do
        local suffix = "." .. extension
        if lower_filepath:sub(-#suffix) == suffix then
            return extension
        end
    end

    return lower_filepath:match("%.([^%.%/]+)$")
end

local function isBookFile(filepath)
    local extension = getBookExtension(filepath)
    return extension and BOOK_EXTENSIONS[extension] or false
end

local function escapeGlobPattern(text)
    return tostring(text):gsub("([%*%?%[%]])", function(char)
        return "[" .. char .. "]"
    end)
end

local function normalizeBaseDir(base_dir)
    while #base_dir > 1 and base_dir:sub(-1) == "/" do
        base_dir = base_dir:sub(1, -2)
    end
    return base_dir
end

local function serializeValue(value)
    if value == false then
        return "boolean:false"
    end
    return type(value) .. ":" .. tostring(value)
end

local function normalizeStatusFilter(options)
    local filter = options and options.filter
    if STATUS_BY_FILTER[filter] then
        return filter
    end
    return "all"
end

local function getStateCacheKey(base_dir, filter_state, options)
    local key = { normalizeBaseDir(base_dir or ""), "trail" }
    for _, filter in ipairs(filter_state and filter_state.trail or {}) do
        table.insert(key, filter.dimension or "")
        table.insert(key, serializeValue(filter.value))
    end
    local status_filter = normalizeStatusFilter(options)
    if status_filter ~= "all" then
        table.insert(key, "status_filter")
        table.insert(key, status_filter)
    end
    return table.concat(key, "\31")
end

local function copyArray(array)
    local copy = {}
    for i, value in ipairs(array or {}) do
        copy[i] = value
    end
    return copy
end

local function clearCacheTable(cache, base_dir)
    if not base_dir then
        for key in pairs(cache) do
            cache[key] = nil
        end
        return
    end

    local prefix = normalizeBaseDir(base_dir) .. "\31"
    for key in pairs(cache) do
        if key:sub(1, #prefix) == prefix then
            cache[key] = nil
        end
    end
end

local function clearPathCacheTable(cache, base_dir)
    if not base_dir then
        for key in pairs(cache) do
            cache[key] = nil
        end
        return
    end

    local prefix = normalizeBaseDir(base_dir)
    if prefix == "/" then
        for key in pairs(cache) do
            cache[key] = nil
        end
        return
    end

    local prefix_with_separator = prefix .. "/"
    for key in pairs(cache) do
        if key == prefix or key:sub(1, #prefix_with_separator) == prefix_with_separator then
            cache[key] = nil
        end
    end
end

function MetadataSource.clearCache(base_dir)
    clearCacheTable(matching_files_cache, base_dir)
    clearCacheTable(facet_values_cache, base_dir)
    clearCacheTable(status_counts_cache, base_dir)
    clearPathCacheTable(file_validity_cache, base_dir)
end

local function copyOptionsWithFilter(options, filter)
    local copy = {}
    for key, value in pairs(options or {}) do
        copy[key] = value
    end
    copy.filter = filter
    return copy
end

local function copyMap(map)
    local copy = {}
    for key, value in pairs(map or {}) do
        copy[key] = value
    end
    return copy
end

local function addFilterSql(sql, vars, dimension, value)
    local definition = FilterState.DIMENSIONS[dimension]
    if not definition then
        return sql
    end

    local column = definition.column
    if value == false then
        return T("%1 and %2 is NULL", sql, column)
    elseif definition.multi_value then
        sql = T("%1 and instr('\n'||%2||'\n', ?) > 0", sql, column)
        table.insert(vars, "\n"..value.."\n")
        return sql
    end

    sql = T("%1 and %2=?", sql, column)
    table.insert(vars, value)
    return sql
end

local function getMatchingFilesCached(book_info_manager, base_dir, filter_state, limit, options)
    if limit ~= nil then
        return MetadataSource.fetchMatchingFiles(book_info_manager, base_dir, filter_state, limit, options)
    end

    local state = filter_state or FilterState.new(base_dir)
    local cache_key = getStateCacheKey(base_dir, state, options)
    if matching_files_cache[cache_key] == nil then
        matching_files_cache[cache_key] = MetadataSource.fetchMatchingFiles(book_info_manager, base_dir, state, nil, options)
    end
    return matching_files_cache[cache_key]
end

local function isValidBookPath(filepath)
    if file_validity_cache[filepath] ~= nil then
        return file_validity_cache[filepath]
    end

    local valid = false
    if isBookFile(filepath) then
        valid = lfs.attributes(filepath, "mode") == "file"
            and DocumentRegistry:hasProvider(filepath)
            or false
    end
    file_validity_cache[filepath] = valid
    return valid
end

local function matchesStatusFilter(filepath, options)
    local status_filter = normalizeStatusFilter(options)
    if status_filter == "all" then
        return true
    end

    local BookList = require("ui/widget/booklist")
    return BookList.getBookStatus(filepath) == STATUS_BY_FILTER[status_filter]
end

function MetadataSource.getFacetValuesWithCount(book_info_manager, base_dir, meta_name, filter_state, options)
    local results = {}
    local grouped = {}
    if not FilterState.isDimension(meta_name) then
        return results, 0
    end

    local state = filter_state or FilterState.new(base_dir, meta_name)
    local query_state = state
    if options and options.exclude_dimension then
        query_state = FilterState.withoutDimension(state, options.exclude_dimension)
    end

    local facet_cache_key = table.concat({
        getStateCacheKey(base_dir, query_state, options),
        "facet",
        meta_name,
    }, "\31")
    local cached = facet_values_cache[facet_cache_key]
    if not cached then
        local matching_files = MetadataSource.getMatchingFiles(book_info_manager, base_dir, query_state, nil, options)
        for _, row in ipairs(matching_files) do
            local definition = FilterState.DIMENSIONS[meta_name]
            if definition.multi_value then
                local values = row[meta_name]
                if values and values:find("\n", 1, true) then
                    for value in util.gsplit(values, "\n") do
                        if value ~= "" then
                            grouped[value] = (grouped[value] or 0) + 1
                        end
                    end
                else
                    local value = values or false
                    grouped[value] = (grouped[value] or 0) + 1
                end
            else
                local value = row.series or false
                grouped[value] = (grouped[value] or 0) + 1
            end
        end

        cached = {
            count = #matching_files,
            values = {},
        }
        for value, nb in pairs(grouped) do
            table.insert(cached.values, {
                value,
                nb,
            })
        end
        facet_values_cache[facet_cache_key] = cached
    end

    local selected = state.selected and state.selected[meta_name]
    for _, value in ipairs(cached.values) do
        table.insert(results, {
            value[1],
            value[2],
            selected = selected and selected[value[1]] or false,
        })
    end
    return results, cached.count
end

function MetadataSource.getFacetValues(book_info_manager, base_dir, meta_name, filter_state, options)
    local results = MetadataSource.getFacetValuesWithCount(book_info_manager, base_dir, meta_name, filter_state, options)
    return results
end

function MetadataSource.getAllFacetValues(book_info_manager, base_dir, filter_state, options)
    local state = filter_state or FilterState.new(base_dir)
    local results = {}
    for _, dimension in ipairs(FilterState.ORDERED_DIMENSIONS) do
        results[dimension] = MetadataSource.getFacetValues(book_info_manager, base_dir, dimension, state, options)
    end
    return results
end

function MetadataSource.getMatchingMetadataValues(book_info_manager, base_dir, meta_name, filter_state, options)
    return MetadataSource.getFacetValues(book_info_manager, base_dir, meta_name, filter_state, options)
end

function MetadataSource.getMatchingFiles(book_info_manager, base_dir, filter_state, limit, options)
    if type(limit) == "table" and options == nil then
        options = limit
        limit = nil
    end
    return copyArray(getMatchingFilesCached(book_info_manager, base_dir, filter_state, limit, options))
end

function MetadataSource.getMatchingFilesCount(book_info_manager, base_dir, filter_state, options)
    return #getMatchingFilesCached(book_info_manager, base_dir, filter_state, nil, options)
end

function MetadataSource.getStatusFilterCounts(book_info_manager, base_dir, filter_state, options)
    if not base_dir then
        return {}
    end

    local state = filter_state or FilterState.new(base_dir)
    local all_options = copyOptionsWithFilter(options, "all")
    local cache_key = table.concat({
        getStateCacheKey(base_dir, state, all_options),
        "status_counts",
    }, "\31")

    if not status_counts_cache[cache_key] then
        local counts = {
            all = 0,
            unread = 0,
            reading = 0,
            finished = 0,
        }
        local filter_by_status = {
            new = "unread",
            reading = "reading",
            complete = "finished",
        }
        local BookList = require("ui/widget/booklist")
        local matching_files = getMatchingFilesCached(book_info_manager, base_dir, state, nil, all_options)
        counts.all = #matching_files
        for _, row in ipairs(matching_files) do
            local filter = filter_by_status[BookList.getBookStatus(row[1])]
            if filter then
                counts[filter] = counts[filter] + 1
            end
        end
        status_counts_cache[cache_key] = counts
    end

    return copyMap(status_counts_cache[cache_key])
end

function MetadataSource.fetchMatchingFiles(book_info_manager, base_dir, filter_state, limit, options)
    if not base_dir then
        return {}
    end
    base_dir = normalizeBaseDir(base_dir)
    local state = filter_state or FilterState.new(base_dir)
    local vars = {}
    local sql = "select directory||filename, filename, title, authors, series, series_index, keywords from bookinfo where directory glob ? and unsupported is NULL"
    table.insert(vars, escapeGlobPattern(base_dir)..'/*')
    for _, filter in ipairs(state.trail or {}) do
        sql = addFilterSql(sql, vars, filter.dimension, filter.value)
    end
    sql = sql .. " order by directory asc, filename asc"
    limit = tonumber(limit)
    if limit then
        sql = sql .. " limit " .. limit
    end
    book_info_manager:openDbConnection()
    local stmt = book_info_manager.db_conn:prepare(sql)
    stmt:bind(table.unpack(vars))
    local results = {}
    while true do
        local row = stmt:step()
        if not row then
            break
        end
        if isValidBookPath(row[1]) and matchesStatusFilter(row[1], options) then
            table.insert(results, {
                row[1],
                row[2],
                title = row[3],
                authors = row[4],
                series = row[5],
                series_index = tonumber(row[6]),
                keywords = row[7],
            })
        end
    end
    return results
end

return MetadataSource
