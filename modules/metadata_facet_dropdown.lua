-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ButtonDialog = require("ui/widget/buttondialog")
local ffiUtil = require("ffi/util")
local FileManager = require("apps/filemanager/filemanager")
local FontOk, Font = pcall(require, "ui/font")
local MetadataSource = require("modules.metadata_source")
local Size = require("ui/size")
local TabOptionDialog = require("modules.tab_option_dialog")
local TabOptionPresenter = require("modules.tab_option_presenter")
local TabViewOptions = require("modules.tab_view_options")
local TextWidgetOk, TextWidget = pcall(require, "ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VirtualPath = require("modules.virtual_path")
local _ = require("gettext")

local MetadataFacetDropdown = {}
local ROW_FONT_FACE = "cfont"
local ROW_FONT_SIZE = 20
local VALUE_LABEL_MAX_CHARS = 32

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

local row_label_width
local row_radio_width

local function measureTextWidth(text, bold)
    if FontOk and TextWidgetOk then
        local widget = TextWidget:new{
            text = text,
            face = Font:getFace(ROW_FONT_FACE, ROW_FONT_SIZE),
            bold = bold or false,
        }
        local width = widget:getSize().w
        widget:free()
        return width
    end
    return #tostring(text or "") * ROW_FONT_SIZE
end

local function getRowLabelWidth()
    if not row_label_width then
        local width = measureTextWidth(_("Book status"), false)
        for _, dimension in ipairs(DIMENSIONS) do
            width = math.max(width, measureTextWidth(dimension.label, false))
        end
        row_label_width = width + 2 * Size.padding.large + Size.padding.default
    end
    return row_label_width
end

local function getRowCountWidth(count)
    return measureTextWidth(tostring(count or 0), false) + 2 * Size.padding.large + Size.padding.default
end

local function getRowRadioWidth()
    if not row_radio_width then
        row_radio_width = math.max(
            measureTextWidth(TabOptionDialog.OPTION_RADIO_SELECTED, false),
            measureTextWidth(TabOptionDialog.OPTION_RADIO_UNSELECTED, false)
        ) + 2 * Size.padding.large + Size.padding.default
    end
    return row_radio_width
end

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
    local tab_key = VirtualPath.getTabKey(path)
    return {
        file_chooser = file_chooser,
        base_dir = base_dir,
        filter_state = filter_state,
        tab_key = tab_key,
        tab_options = TabViewOptions.getMetadataOptions(tab_key),
    }
end

local function countAvailableValues(values)
    local available_count = 0
    for _, value in ipairs(values) do
        if not value.selected then
            available_count = available_count + 1
        end
    end
    return available_count
end

local function getMetadataValuesWithCount(state, dimension)
    local BookInfoManager = require("bookinfomanager")
    return MetadataSource.getFacetValuesWithCount(
        BookInfoManager,
        state.base_dir,
        dimension.key,
        state.filter_state,
        state.tab_options
    )
end

local function getAvailableMetadataValueCount(state, dimension)
    local values = getMetadataValuesWithCount(state, dimension)
    return countAvailableValues(values)
end

local function getAvailableMetadataValues(state, dimension)
    local values, result_count = getMetadataValuesWithCount(state, dimension)
    sortMetadataValues(values)
    return values, countAvailableValues(values), result_count
end

local function getMetadataFilterCounts(state)
    local BookInfoManager = require("bookinfomanager")
    return MetadataSource.getStatusFilterCounts(
        BookInfoManager,
        state.base_dir,
        state.filter_state,
        state.tab_options
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

local function getTextColumnWidth(values)
    local width = 0
    for _, value in ipairs(values) do
        local text = type(value) == "table" and value.text or value
        width = math.max(width, measureTextWidth(text, false))
    end
    local max_width = measureTextWidth(string.rep("W", VALUE_LABEL_MAX_CHARS), false)
    return math.min(width, max_width) + 2 * Size.padding.large + Size.padding.default
end

local function makeNavigationRow(text, count, callback, enabled, count_width, label_width)
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
            width = label_width or getRowLabelWidth(),
            avoid_text_truncation = false,
            callback = callback or function() end,
        },
        {
            text = tostring(count or 0),
            align = "left",
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            font_bold = false,
            enabled = enabled,
            no_vertical_sep = true,
            width = count_width or getRowCountWidth(count),
            avoid_text_truncation = false,
            callback = callback or function() end,
        },
        {
            text = "",
            enabled = false,
            no_vertical_sep = true,
            callback = function() end,
        },
    }
end

local function makeSummaryRow(label, value, callback)
    return {
        {
            text = label,
            align = "left",
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            font_bold = false,
            no_vertical_sep = true,
            width = getRowLabelWidth(),
            avoid_text_truncation = false,
            callback = callback,
        },
        {
            text = value,
            align = "left",
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            font_bold = true,
            avoid_text_truncation = false,
            callback = callback,
        },
    }
end

local function makeSeparatorRow()
    return {}
end

local function refreshAfterOptionChange(state)
    if state.file_chooser and state.file_chooser.refreshPath then
        state.file_chooser:refreshPath()
    end
end

local showDimensionDropdown

local function showTabOptionValues(file_manager, anchor, field)
    local state = getDropdownState(file_manager)
    if not state then
        return
    end

    local option_field = TabOptionPresenter.getOptionField(state.tab_key, field)
    local current_value = state.tab_options[option_field]
    local filter_counts
    local count_width
    if field == "filter" then
        filter_counts = getMetadataFilterCounts(state)
        local max_count = 0
        for _, value in ipairs(TabOptionPresenter.getFieldValues(state.tab_key, field)) do
            max_count = math.max(max_count, filter_counts[value] or 0)
        end
        count_width = getRowCountWidth(max_count)
    end

    TabOptionDialog.showValues{
        anchor = anchor,
        values = TabOptionPresenter.getFieldValues(state.tab_key, field),
        current_value = current_value,
        radio_width = getRowRadioWidth(),
        getLabel = function(value)
            return TabOptionPresenter.getValueLabel(state.tab_key, field, value)
        end,
        getCount = filter_counts and function(value)
            return filter_counts[value]
        end or nil,
        getCountWidth = function(_value, count)
            return count_width or getRowCountWidth(count)
        end,
        style = {
            font_face = ROW_FONT_FACE,
            font_size = ROW_FONT_SIZE,
            avoid_text_truncation = false,
        },
        onBack = function()
            showDimensionDropdown(file_manager, anchor)
        end,
        onSelect = function(value)
            TabViewOptions.set(state.tab_key, option_field, value)
            refreshAfterOptionChange(state)
        end,
        onSelected = function()
            showTabOptionValues(file_manager, anchor, field)
        end,
    }
end

showDimensionDropdown = function(file_manager, anchor)
    local state = getDropdownState(file_manager)
    if not state then
        return
    end

    local dialog
    local buttons = {}
    local function showOptionValues(field)
        if dialog then
            UIManager:close(dialog)
        end
        showTabOptionValues(file_manager, anchor, field)
    end
    table.insert(buttons, makeSummaryRow(
        TabOptionPresenter.getSummaryLabel("filter"),
        TabOptionPresenter.getFilterLabel(state.tab_options.filter),
        function()
            showOptionValues("filter")
        end
    ))
    table.insert(buttons, makeSeparatorRow())

    local dimension_counts = {}
    local max_count = 0
    for _, dimension in ipairs(DIMENSIONS) do
        local available_count = getAvailableMetadataValueCount(state, dimension)
        dimension_counts[dimension.key] = available_count
        max_count = math.max(max_count, available_count)
    end
    local count_width = getRowCountWidth(max_count)
    local has_dimension_rows = false
    for _, dimension in ipairs(DIMENSIONS) do
        local dimension_ref = dimension
        local available_count = dimension_counts[dimension_ref.key]
        if available_count > 0 then
            has_dimension_rows = true
            table.insert(buttons, makeNavigationRow(dimension_ref.label, available_count, function()
                if dialog then
                    UIManager:close(dialog)
                end
                MetadataFacetDropdown.showValues(file_manager, anchor, dimension_ref)
            end, true, count_width))
        end
    end
    if not has_dimension_rows then
        table.insert(buttons, {{
            text = _("No relevant filters"),
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

    local values, _available_count, current_result_count = getAvailableMetadataValues(state, dimension)

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

    local max_count = 0
    local value_labels = {}
    for _, value in ipairs(values) do
        if not value.selected then
            max_count = math.max(max_count, value[2] or 0)
            table.insert(value_labels, VirtualPath.displayValue(value[1]))
        end
    end
    local count_width = getRowCountWidth(max_count)
    local label_width = getTextColumnWidth(value_labels)

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
        end, enabled, count_width, label_width))
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
