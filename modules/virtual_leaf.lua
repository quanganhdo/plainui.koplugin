-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local VirtualLeaf = {}

function VirtualLeaf.markMetadataLeaf(item, count, title)
    if not item then
        return item
    end
    item.is_virtual_metadata_leaf = true
    item.virtual_leaf_count = count
    item.virtual_leaf_title = title
    return item
end

function VirtualLeaf.ensureRepresentativeFilepath(item, cover_browser)
    local entry = item and (item.entry or item)
    if not entry or not entry.is_virtual_metadata_leaf then
        return
    end
    if entry.representative_filepath or entry.representative_filepath_checked then
        return entry.representative_filepath
    end

    entry.representative_filepath_checked = true
    if not entry.path or not cover_browser or not cover_browser.getRepresentativeFilepath then
        return
    end

    local representative_path = cover_browser:getRepresentativeFilepath(entry.path)
    if representative_path then
        entry.representative_filepath = representative_path
    end
    return representative_path
end

return VirtualLeaf
