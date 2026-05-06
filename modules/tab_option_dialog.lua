-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local TabOptionDialog = {}

local OPTION_RADIO_SELECTED = "\u{25c9}"
local OPTION_RADIO_UNSELECTED = "\u{25ef}"

local function applyTextStyle(cell, style)
    style = style or {}
    if style.font_face then
        cell.font_face = style.font_face
    end
    if style.font_size then
        cell.font_size = style.font_size
    end
    if style.avoid_text_truncation ~= nil then
        cell.avoid_text_truncation = style.avoid_text_truncation
    end
    return cell
end

function TabOptionDialog.showValues(args)
    local dialog
    local style = args.style or {}
    local buttons = {
        { applyTextStyle({
            text = args.back_text or _("Back"),
            align = "left",
            font_bold = true,
            callback = function()
                if dialog then
                    UIManager:close(dialog)
                end
                args.onBack()
            end,
        }, style) },
    }

    for _, value in ipairs(args.values or {}) do
        local value_ref = value
        local selected = value_ref == args.current_value
        local function selectValue()
            if dialog then
                UIManager:close(dialog)
            end
            args.onSelect(value_ref)
            if args.onSelected then
                args.onSelected(value_ref)
            end
        end
        local row = {
            applyTextStyle({
                text = selected and OPTION_RADIO_SELECTED or OPTION_RADIO_UNSELECTED,
                align = "center",
                font_bold = false,
                no_vertical_sep = true,
                width = args.radio_width,
                callback = selectValue,
            }, style),
            applyTextStyle({
                text = args.getLabel(value_ref),
                align = "left",
                font_bold = false,
                no_vertical_sep = true,
                callback = selectValue,
            }, style),
        }
        if args.getCount then
            local count = args.getCount(value_ref)
            if count ~= nil then
                table.insert(row, applyTextStyle({
                    text = tostring(count),
                    align = "left",
                    font_bold = false,
                    width = args.getCountWidth and args.getCountWidth(value_ref, count) or args.count_width,
                    callback = selectValue,
                }, style))
            end
        end
        table.insert(buttons, row)
    end

    dialog = ButtonDialog:new{
        shrink_unneeded_width = true,
        buttons = buttons,
        anchor = args.anchor,
    }
    UIManager:show(dialog)
    return dialog
end

TabOptionDialog.OPTION_RADIO_SELECTED = OPTION_RADIO_SELECTED
TabOptionDialog.OPTION_RADIO_UNSELECTED = OPTION_RADIO_UNSELECTED

return TabOptionDialog
