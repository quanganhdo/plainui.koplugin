-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ReadCollection = require("readcollection")
local _ = require("gettext")

local VirtualPath = {}

VirtualPath.ROOT_SYMBOL = "\u{e257}"
VirtualPath.AUTHOR_SYMBOL = "\u{f2c0}"
VirtualPath.SERIES_SYMBOL = "\u{ecd7}"
VirtualPath.KEYWORD_SYMBOL = "\u{f412}"
VirtualPath.COLLECTION_SYMBOL = "\u{f02d}"
VirtualPath.EMPTY_VALUE_SYMBOL = "\u{2205}"

local META_BY_SYMBOL = {
    [VirtualPath.AUTHOR_SYMBOL] = "authors",
    [VirtualPath.SERIES_SYMBOL] = "series",
    [VirtualPath.KEYWORD_SYMBOL] = "keywords",
    [VirtualPath.COLLECTION_SYMBOL] = "collections",
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

function VirtualPath.getCollectionTitle(collection_name)
    if collection_name == false or collection_name == nil then
        return VirtualPath.EMPTY_VALUE_SYMBOL
    end
    return collection_name == ReadCollection.default_collection_name and _("Favorites") or collection_name
end

function VirtualPath.findRoot(path)
    if not path then
        return
    end
    return path:find("/" .. VirtualPath.ROOT_SYMBOL, 1, true)
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

function VirtualPath.parse(path)
    local root_start, root_end = VirtualPath.findRoot(path)
    if not root_start then
        return
    end
    local base_dir = path:sub(1, root_start - 1)
    local fragments = VirtualPath.getFragments(path) or {}

    local meta_name
    local filters = {}
    local filters_seen = {}
    local cur_value
    while #fragments > 0 do
        local fragment = table.remove(fragments)
        local db_meta_name = META_BY_SYMBOL[fragment]
        if fragment == VirtualPath.ROOT_SYMBOL then
            do end
        elseif db_meta_name then
            if cur_value ~= nil then
                table.insert(filters, { db_meta_name, cur_value })
                if not filters_seen[db_meta_name] then
                    filters_seen[db_meta_name] = {}
                end
                filters_seen[db_meta_name][cur_value] = true
            else
                meta_name = db_meta_name
            end
        else
            cur_value = VirtualPath.decodeValue(fragment)
        end
    end
    return base_dir, meta_name, filters, filters_seen
end

return VirtualPath
