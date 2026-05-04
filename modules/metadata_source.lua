-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ffiUtil = require("ffi/util")
local DocumentRegistry = require("document/documentregistry")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local T = ffiUtil.template

local MetadataSource = {}

function MetadataSource.getMatchingMetadataValues(book_info_manager, base_dir, meta_name, filters)
    local results = {}
    local grouped = {}
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
    local vars = {}
    local sql = "select directory||filename, filename, title, authors, series, series_index, keywords from bookinfo where directory glob ? and unsupported is NULL"
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
        if lfs.attributes(row[1], "mode") == "file" and DocumentRegistry:hasProvider(row[1]) then
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
