-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local VirtualPath = {}

local FilterState = require("modules.filter_state")

VirtualPath.ROOT_SYMBOL = "\u{e257}"
VirtualPath.AUTHOR_SYMBOL = "\u{f2c0}"
VirtualPath.SERIES_SYMBOL = "\u{ecd7}"
VirtualPath.KEYWORD_SYMBOL = "\u{f412}"
VirtualPath.EMPTY_VALUE_SYMBOL = "\u{2205}"

local META_BY_SYMBOL = {
    [VirtualPath.AUTHOR_SYMBOL] = "authors",
    [VirtualPath.SERIES_SYMBOL] = "series",
    [VirtualPath.KEYWORD_SYMBOL] = "keywords",
}

local SYMBOL_BY_META = {
    authors = VirtualPath.AUTHOR_SYMBOL,
    series = VirtualPath.SERIES_SYMBOL,
    keywords = VirtualPath.KEYWORD_SYMBOL,
}

function VirtualPath.encodeValue(value)
    if value == false or value == nil then
        return VirtualPath.EMPTY_VALUE_SYMBOL
    end
    value = tostring(value)
    if value == "" then
        return "%EMPTY%"
    end
    return (value:gsub("([^A-Za-z0-9%._%-%~])", function(char)
        return string.format("%%%02X", char:byte())
    end))
end

function VirtualPath.decodeValue(fragment)
    if fragment == VirtualPath.EMPTY_VALUE_SYMBOL then
        return false
    end
    if fragment == "%EMPTY%" then
        return ""
    end
    return (fragment:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

function VirtualPath.displayValue(value)
    if value == false or value == nil then
        return VirtualPath.EMPTY_VALUE_SYMBOL
    end
    return tostring(value)
end

function VirtualPath.getLeafEntry(filter_state)
    local trail = filter_state and filter_state.trail
    return trail and trail[#trail]
end

function VirtualPath.findRoot(path)
    if not path then
        return
    end
    local pattern = "/" .. VirtualPath.ROOT_SYMBOL
    local init = 1
    while true do
        local root_start, root_end = path:find(pattern, init, true)
        if not root_start then
            return
        end
        local next_char = path:sub(root_end + 1, root_end + 1)
        if next_char == "" or next_char == "/" then
            return root_start, root_end
        end
        init = root_end + 1
    end
end

function VirtualPath.getFragments(path)
    local _root_start, root_end = VirtualPath.findRoot(path)
    if not root_end then
        return
    end

    local fragments = {}
    for fragment in path:sub(root_end + 1):gmatch("[^/]+") do
        table.insert(fragments, fragment)
    end
    return fragments
end

function VirtualPath.getBaseDir(path)
    if not path then
        return
    end
    local root_start = VirtualPath.findRoot(path)
    if root_start then
        return path:sub(1, root_start - 1)
    end
    return path
end

function VirtualPath.getVirtualBaseDir(path)
    if not path then
        return
    end
    local root_start = VirtualPath.findRoot(path)
    if root_start then
        return path:sub(1, root_start - 1)
    end
end

function VirtualPath.getBrowsePath(base_dir, item)
    if not base_dir or not item then
        return
    end
    return string.format("%s/%s/%s", base_dir, VirtualPath.ROOT_SYMBOL, item.symbol)
end

function VirtualPath.getDimensionSymbol(dimension)
    return SYMBOL_BY_META[dimension]
end

function VirtualPath.buildFilterStatePath(base_dir, filter_state)
    local fragments = {
        base_dir,
        VirtualPath.ROOT_SYMBOL,
    }
    for _, entry in ipairs(filter_state and filter_state.trail or {}) do
        local symbol = VirtualPath.getDimensionSymbol(entry.dimension)
        if symbol then
            table.insert(fragments, symbol)
            table.insert(fragments, VirtualPath.encodeValue(entry.value))
        end
    end
    return table.concat(fragments, "/")
end

function VirtualPath.buildFilteredPath(base_dir, filter_state, dimension, value)
    local state = FilterState.clone(filter_state or FilterState.new(base_dir))
    FilterState.addFilter(state, dimension, value)
    return VirtualPath.buildFilterStatePath(base_dir, state)
end

function VirtualPath.buildPreviousFilterPath(base_dir, filter_state)
    local trail = filter_state and filter_state.trail or {}
    if #trail == 1 then
        local symbol = VirtualPath.getDimensionSymbol(trail[1].dimension)
        if symbol then
            return table.concat({
                base_dir,
                VirtualPath.ROOT_SYMBOL,
                symbol,
            }, "/")
        end
    end

    local previous_state = FilterState.new(base_dir)
    for i = 1, #trail - 1 do
        local entry = trail[i]
        FilterState.addFilter(previous_state, entry.dimension, entry.value)
    end
    return VirtualPath.buildFilterStatePath(base_dir, previous_state)
end

function VirtualPath.parse(path)
    local root_start, root_end = VirtualPath.findRoot(path)
    if not root_start then
        return
    end
    local base_dir = path:sub(1, root_start - 1)
    local fragments = VirtualPath.getFragments(path) or {}

    local state = FilterState.new(base_dir)
    local pending_dimension
    for _, fragment in ipairs(fragments) do
        local db_meta_name = META_BY_SYMBOL[fragment]
        if fragment == VirtualPath.ROOT_SYMBOL then
            do end
        elseif db_meta_name then
            pending_dimension = db_meta_name
        elseif pending_dimension then
            FilterState.addFilter(state, pending_dimension, VirtualPath.decodeValue(fragment))
            pending_dimension = nil
        else
            do end
        end
    end
    state.active_dimension = pending_dimension

    return base_dir, state.active_dimension, state
end

return VirtualPath
