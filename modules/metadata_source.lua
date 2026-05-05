-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ffiUtil = require("ffi/util")
local DocumentRegistry = require("document/documentregistry")
local FilterState = require("modules.filter_state")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local T = ffiUtil.template

local MetadataSource = {}

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

function MetadataSource.getFacetValues(book_info_manager, base_dir, meta_name, filter_state, options)
    local results = {}
    local grouped = {}
    if not FilterState.isDimension(meta_name) then
        return results
    end

    local state = filter_state or FilterState.new(base_dir, meta_name)
    local query_state = state
    if options and options.exclude_dimension then
        query_state = FilterState.withoutDimension(state, options.exclude_dimension)
    end

    local matching_files = MetadataSource.getMatchingFiles(book_info_manager, base_dir, query_state)
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

    local selected = state.selected and state.selected[meta_name]
    for value, nb in pairs(grouped) do
        table.insert(results, {
            value,
            nb,
            selected = selected and selected[value] or false,
        })
    end
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

function MetadataSource.getMatchingMetadataValues(book_info_manager, base_dir, meta_name, filter_state)
    return MetadataSource.getFacetValues(book_info_manager, base_dir, meta_name, filter_state)
end

function MetadataSource.getMatchingFiles(book_info_manager, base_dir, filter_state, limit)
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
        if lfs.attributes(row[1], "mode") == "file" and isBookFile(row[1]) and DocumentRegistry:hasProvider(row[1]) then
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
