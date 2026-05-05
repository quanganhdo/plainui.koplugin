-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ButtonDialog = require("ui/widget/buttondialog")
local ffiUtil = require("ffi/util")
local FileManager = require("apps/filemanager/filemanager")
local MetadataSource = require("modules.metadata_source")
local UIManager = require("ui/uimanager")
local VirtualPath = require("modules.virtual_path")
local _ = require("gettext")

local MetadataFacetDropdown = {}
local ROW_FONT_FACE = "cfont"
local ROW_FONT_SIZE = 20

local DIMENSIONS = {
    {
        key = "authors",
        label = _("Authors"),
    },
    {
        key = "series",
        label = _("Series"),
    },
    {
        key = "keywords",
        label = _("Tags"),
    },
}

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

local function sortMetadataValues(values)
    table.sort(values, function(a, b)
        local av = a[1]
        local bv = b[1]
        if av == false or av == nil then
            return false
        elseif bv == false or bv == nil then
            return true
        end
        if av == bv then
            return (a[2] or 0) < (b[2] or 0)
        end
        return virtualTextLess(av, bv)
    end)
end

local function getDropdownState(file_manager)
    file_manager = file_manager or FileManager.instance
    local file_chooser = file_manager and file_manager.file_chooser
    local path = file_chooser and file_chooser.path
    local base_dir, active_dimension, filter_state = VirtualPath.parse(path)
    if not base_dir or active_dimension then
        return
    end
    if not VirtualPath.getLeafEntry(filter_state) then
        return
    end
    return {
        file_chooser = file_chooser,
        base_dir = base_dir,
        filter_state = filter_state,
    }
end

local function getAvailableMetadataValues(state, dimension)
    local BookInfoManager = require("bookinfomanager")
    local values = MetadataSource.getMatchingMetadataValues(
        BookInfoManager,
        state.base_dir,
        dimension.key,
        state.filter_state
    )
    sortMetadataValues(values)
    local available_count = 0
    for _, value in ipairs(values) do
        if not value.selected then
            available_count = available_count + 1
        end
    end
    return values, available_count
end

local function getCurrentResultCount(state)
    local BookInfoManager = require("bookinfomanager")
    return #MetadataSource.getMatchingFiles(
        BookInfoManager,
        state.base_dir,
        state.filter_state
    )
end

local function splitValuesByNarrowing(values, current_result_count)
    local useful_values = {}
    local non_narrowing_values = {}
    for _, value in ipairs(values) do
        if not value.selected then
            if (value[2] or 0) >= current_result_count then
                table.insert(non_narrowing_values, value)
            else
                table.insert(useful_values, value)
            end
        end
    end
    return useful_values, non_narrowing_values
end

local function makeNavigationRow(text, count, callback, enabled)
    enabled = enabled ~= false
    return {
        {
            text = text,
            align = "left",
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            font_bold = false,
            enabled = enabled,
            no_vertical_sep = true,
            callback = callback or function() end,
        },
        {
            text = tostring(count or 0),
            align = "center",
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            font_bold = false,
            enabled = enabled,
            width = 64,
            callback = callback or function() end,
        },
    }
end

local function showDimensionDropdown(file_manager, anchor)
    local state = getDropdownState(file_manager)
    if not state then
        return
    end

    local dialog
    local buttons = {}
    for _, dimension in ipairs(DIMENSIONS) do
        local dimension_ref = dimension
        local _values, available_count = getAvailableMetadataValues(state, dimension_ref)
        if available_count > 0 then
            table.insert(buttons, makeNavigationRow(dimension_ref.label, available_count, function()
                if dialog then
                    UIManager:close(dialog)
                end
                MetadataFacetDropdown.showValues(file_manager, anchor, dimension_ref)
            end))
        end
    end
    if #buttons == 0 then
        table.insert(buttons, {{
            text = _("No filters"),
            align = "left",
            font_bold = false,
            enabled = false,
        }})
    end

    dialog = ButtonDialog:new{
        shrink_unneeded_width = true,
        buttons = buttons,
        anchor = anchor,
    }
    UIManager:show(dialog)
end

function MetadataFacetDropdown.show(file_manager, anchor)
    showDimensionDropdown(file_manager, anchor)
end

function MetadataFacetDropdown.showValues(file_manager, anchor, dimension)
    local state = getDropdownState(file_manager)
    if not state or not dimension then
        return
    end

    local values = getAvailableMetadataValues(state, dimension)
    local current_result_count = getCurrentResultCount(state)

    local dialog
    local buttons = {
        {{
            text = _("Back"),
            align = "left",
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            font_bold = true,
            callback = function()
                if dialog then
                    UIManager:close(dialog)
                end
                showDimensionDropdown(file_manager, anchor)
            end,
        }},
    }
    local useful_values, non_narrowing_values = splitValuesByNarrowing(values, current_result_count)

    local function addValueRow(value, enabled)
        local value_key = value[1]
        table.insert(buttons, makeNavigationRow(VirtualPath.displayValue(value_key), value[2], function()
            if dialog then
                UIManager:close(dialog)
            end
            state.file_chooser:changeToPath(VirtualPath.buildFilteredPath(
                state.base_dir,
                state.filter_state,
                dimension.key,
                value_key
            ))
        end, enabled))
    end

    for _, value in ipairs(useful_values) do
        addValueRow(value, true)
    end
    for _, value in ipairs(non_narrowing_values) do
        addValueRow(value, false)
    end
    if #buttons == 1 then
        table.insert(buttons, {{
            text = _("No values"),
            align = "left",
            font_bold = false,
            enabled = false,
        }})
    end

    dialog = ButtonDialog:new{
        shrink_unneeded_width = true,
        rows_per_page = { 12, 10, 8 },
        buttons = buttons,
        anchor = anchor,
    }
    UIManager:show(dialog)
end

MetadataFacetDropdown._test = {
    splitValuesByNarrowing = splitValuesByNarrowing,
}

return MetadataFacetDropdown
