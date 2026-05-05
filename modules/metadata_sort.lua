-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ffiUtil = require("ffi/util")

local MetadataSort = {}

local function virtualTextLess(a, b)
    if a == b then
        return false
    elseif a == nil or a == false or a == "" then
        return false
    elseif b == nil or b == false or b == "" then
        return true
    end
    return ffiUtil.strcoll(a, b)
end

function MetadataSort.sortFacetValues(values, folder_sort)
    table.sort(values, function(a, b)
        local av = a[1]
        local bv = b[1]
        if av == false or av == nil then
            return false
        elseif bv == false or bv == nil then
            return true
        end

        if folder_sort == "book_count" then
            local ac = a[2] or 0
            local bc = b[2] or 0
            if ac ~= bc then
                return ac > bc
            end
        end

        if av == bv then
            return (a[2] or 0) < (b[2] or 0)
        end
        return virtualTextLess(av, bv)
    end)
end

MetadataSort._test = {
    virtualTextLess = virtualTextLess,
}

return MetadataSort
