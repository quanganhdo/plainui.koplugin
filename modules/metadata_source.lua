-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local ReadCollection = require("readcollection")
local util = require("util")
local VirtualPath = require("modules.virtual_path")

local T = ffiUtil.template

local MetadataSource = {}

local function refreshCollections()
    if ReadCollection._read then
        ReadCollection:_read()
    end
end

local function isFileInBaseDir(filepath, base_dir)
    if not filepath or not base_dir then
        return false
    end
    if base_dir == "/" then
        return filepath:sub(1, 1) == "/"
    end
    return filepath:sub(1, #base_dir + 1) == base_dir .. "/"
end

local function getCollectedFileSet(base_dir)
    refreshCollections()
    local collected = {}
    for _, collection in pairs(ReadCollection.coll or {}) do
        for filepath in pairs(collection) do
            if isFileInBaseDir(filepath, base_dir) and lfs.attributes(filepath, "mode") == "file" then
                collected[filepath] = true
            end
        end
    end
    return collected
end

local function getBaseDirBookInfoRows(book_info_manager, base_dir)
    if not base_dir then
        return {}
    end

    local sql = "select directory||filename, filename, title, authors, series, series_index, keywords from bookinfo where directory glob ? order by directory asc, filename asc"
    book_info_manager:openDbConnection()
    local stmt = book_info_manager.db_conn:prepare(sql)
    stmt:bind(base_dir..'/*')
    local rows = {}
    while true do
        local row = stmt:step()
        if not row then
            break
        end
        if lfs.attributes(row[1], "mode") == "file" then
            table.insert(rows, {
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
    return rows
end

local function getCollectionFilter(filters)
    for idx, filter in ipairs(filters or {}) do
        if filter[1] == "collections" then
            return filter[2], idx
        end
    end
end

local function valueMatchesMultiValueField(field, value)
    if value == false then
        return field == nil
    end
    if not field then
        return false
    end
    if field:find("\n", 1, true) then
        for field_value in util.gsplit(field, "\n") do
            if field_value == value then
                return true
            end
        end
        return false
    end
    return field == value
end

local function matchingFilePassesFilter(row, filter)
    local name, value = filter[1], filter[2]
    if name == "authors" then
        return valueMatchesMultiValueField(row.authors, value)
    elseif name == "keywords" then
        return valueMatchesMultiValueField(row.keywords, value)
    elseif name == "series" then
        return value == false and row.series == nil or row.series == value
    end
    return true
end

local function makeMatchingFileRow(book_info_manager, filepath, collection_order)
    local attributes = lfs.attributes(filepath)
    if not attributes or attributes.mode ~= "file" then
        return
    end
    local _directory, filename = util.splitFilePathName(filepath)
    local bookinfo = book_info_manager:getBookInfo(filepath, false) or {}
    return {
        filepath,
        filename,
        title = bookinfo.title,
        authors = bookinfo.authors,
        series = bookinfo.series,
        series_index = tonumber(bookinfo.series_index),
        keywords = bookinfo.keywords,
        collection_order = collection_order,
    }
end

local function getMatchingCollectionValues(book_info_manager, base_dir)
    refreshCollections()
    local results = {}
    for collection_name, collection in pairs(ReadCollection.coll or {}) do
        local count = 0
        for filepath in pairs(collection) do
            if isFileInBaseDir(filepath, base_dir) and lfs.attributes(filepath, "mode") == "file" then
                count = count + 1
            end
        end
        if count > 0 then
            local settings = ReadCollection.coll_settings and ReadCollection.coll_settings[collection_name] or {}
            table.insert(results, {
                collection_name,
                count,
                display_name = VirtualPath.getCollectionTitle(collection_name),
                order = settings.order or 0,
            })
        end
    end

    local collected = getCollectedFileSet(base_dir)
    local uncollected_count = 0
    for _, row in ipairs(getBaseDirBookInfoRows(book_info_manager, base_dir)) do
        if not collected[row[1]] then
            uncollected_count = uncollected_count + 1
        end
    end
    if uncollected_count > 0 then
        table.insert(results, {
            false,
            uncollected_count,
            display_name = VirtualPath.EMPTY_VALUE_SYMBOL,
            order = math.huge,
        })
    end

    return results
end

local function getCollectionMatchingFiles(book_info_manager, base_dir, filters, limit)
    local collection_name, collection_filter_idx = getCollectionFilter(filters)
    local results = {}

    if collection_name == false then
        local collected = getCollectedFileSet(base_dir)
        for _, row in ipairs(getBaseDirBookInfoRows(book_info_manager, base_dir)) do
            if not collected[row[1]] then
                local passes = true
                for idx, filter in ipairs(filters or {}) do
                    if idx ~= collection_filter_idx and not matchingFilePassesFilter(row, filter) then
                        passes = false
                        break
                    end
                end
                if passes then
                    table.insert(results, row)
                    if limit and #results >= limit then
                        break
                    end
                end
            end
        end
        return results
    end

    if not collection_name then
        return results
    end

    refreshCollections()
    local collection = ReadCollection.coll and ReadCollection.coll[collection_name]
    if not collection then
        return results
    end

    for filepath, collection_item in pairs(collection) do
        if isFileInBaseDir(filepath, base_dir) then
            local row = makeMatchingFileRow(book_info_manager, filepath, collection_item.order)
            if row then
                local passes = true
                for idx, filter in ipairs(filters or {}) do
                    if idx ~= collection_filter_idx and not matchingFilePassesFilter(row, filter) then
                        passes = false
                        break
                    end
                end
                if passes then
                    table.insert(results, row)
                    if limit and #results >= limit then
                        break
                    end
                end
            end
        end
    end
    return results
end

function MetadataSource.getMatchingMetadataValues(book_info_manager, base_dir, meta_name, filters)
    local results = {}
    local grouped = {}
    if meta_name == "collections" then
        return getMatchingCollectionValues(book_info_manager, base_dir)
    end
    if meta_name ~= "authors" and meta_name ~= "series" and meta_name ~= "keywords" then
        return results
    end

    local matching_files = MetadataSource.getMatchingFiles(book_info_manager, base_dir, filters)
    for _, row in ipairs(matching_files) do
        if meta_name == "authors" or meta_name == "keywords" then
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

    for value, nb in pairs(grouped) do
        table.insert(results, {value, nb})
    end
    return results
end

function MetadataSource.getMatchingFiles(book_info_manager, base_dir, filters, limit)
    if not base_dir then
        return {}
    end
    filters = filters or {}
    local _, collection_filter_idx = getCollectionFilter(filters)
    if collection_filter_idx then
        return getCollectionMatchingFiles(book_info_manager, base_dir, filters, limit)
    end
    local vars = {}
    local sql = "select directory||filename, filename, title, authors, series, series_index, keywords from bookinfo where directory glob ?"
    table.insert(vars, base_dir..'/*')
    for _, filter in ipairs(filters) do
        local name, value = filter[1], filter[2]
        if value == false then
            sql = T("%1 and %2 is NULL", sql, name)
        elseif name == "authors" or name == "keywords" then
            -- authors and keywords may have multiple values, separated by \n
            sql = T("%1 and '\n'||%2||'\n' GLOB ?", sql, name)
            table.insert(vars, "*\n"..value.."\n*")
        else
            sql = T("%1 and %2=?", sql, name)
            table.insert(vars, value)
        end
    end
    sql = sql .. " order by directory asc, filename asc"
    if limit then
        sql = sql .. " limit " .. tonumber(limit)
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
        if lfs.attributes(row[1], "mode") == "file" then
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
