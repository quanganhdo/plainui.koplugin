-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconButton = require("ui/widget/iconbutton")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Math = require("optmath")
local Notification = require("ui/widget/notification")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local Screen = Device.screen
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local C_ = _.pgettext

local OpticalCenterContainer = CenterContainer:extend{
    y_offset = 0,
}

function OpticalCenterContainer:paintTo(bb, x, y)
    return CenterContainer.paintTo(self, bb, x, y + self.y_offset)
end

local ALIGNMENT_TWEAKS = {
    "text_align_most_left",
    "text_align_all_left",
    "text_align_most_justify",
    "text_align_all_justify",
}

local COMMON_ALIGNMENT_CSS = {
    text_align_most_left = [[
body, p, li, div, blockquote, section, article {
    text-align: left !important;
}
]],
    text_align_most_justify = [[
body, p, li, div, blockquote, section, article {
    text-align: justify !important;
}
pre {
    -cr-only-if: txt-document;
        text-align: justify !important;
        white-space: normal;
}
]],
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function roundToStep(value, minimum, step)
    return minimum + Math.round((value - minimum) / step) * step
end

local function valuesMatch(left, right)
    return math.abs((tonumber(left) or 0) - (tonumber(right) or 0)) < 0.001
end

local function formatRawValue(value)
    return string.format("%g", value)
end

local function getPrimaryValueFace(size)
    return Font:getFace("NotoSerif-Bold.ttf", size)
        or Font:getFace("tfont", size)
end

local function getDocumentFontFace(ui, size)
    local cre = require("document/credocument"):engineInit()
    local face = ui.font.font_face
    local filename, faceindex = cre.getFontFaceFilenameAndFaceIndex(face)
    if not filename then
        filename, faceindex = cre.getFontFaceFilenameAndFaceIndex(face, nil, true)
    end
    if filename then
        return Font:getFace(filename, size, faceindex)
    end
    return getPrimaryValueFace(size)
end

local FontNameButton = InputContainer:extend{}

function FontNameButton:init()
    self.text_widget = TextWidget:new{
        text = self.text,
        face = self.face,
        max_width = self.max_width,
    }
    self[1] = CenterContainer:new{
        dimen = Geom:new{ w = self.text_widget:getSize().w, h = self.height },
        self.text_widget,
    }
    self.dimen = self[1]:getSize()
    self.ges_events = {
        TapFontName = {
            GestureRange:new{ ges = "tap", range = self.dimen },
        },
    }
end

function FontNameButton:setFont(text, face)
    self.text = text
    self.face = face
    self.text_widget.text = text
    self.text_widget.face = face
    self.text_widget:free()
    self[1].dimen.w = self.text_widget:getSize().w
    self.dimen = self[1]:getSize()
end

function FontNameButton:onTapFontName()
    self.callback()
    return true
end

local FontPreviewItem = InputContainer:extend{}

function FontPreviewItem:init()
    self.selected = self.entry ~= nil and self.selected == true
    self.mark_widget = TextWidget:new{
        text = self.entry and (self.selected and "◉" or "○") or "",
        face = Font:getFace("smallinfofont", 18),
    }
    local sample_face = self.entry and self.entry.font_filename
        and Font:getFace(self.entry.font_filename, self.font_size, self.entry.font_faceindex)
        or Font:getFace("smallinfofont", self.font_size)
    self.text_widget = TextWidget:new{
        text = self.entry and self.entry.text or "",
        face = sample_face,
        max_width = self.width - Screen:scaleBySize(28) - Size.padding.large,
    }
    local mark_width = Screen:scaleBySize(28)
    self[1] = FrameContainer:new{
        width = self.width,
        height = self.height,
        bordersize = 0,
        padding = 0,
        HorizontalGroup:new{
            CenterContainer:new{
                dimen = Geom:new{ w = mark_width, h = self.height },
                self.mark_widget,
            },
            LeftContainer:new{
                dimen = Geom:new{ w = self.width - mark_width, h = self.height },
                self.text_widget,
            },
        },
    }
    self.dimen = self[1]:getSize()
    self.ges_events = {
        TapSelectFont = {
            GestureRange:new{ ges = "tap", range = self.dimen },
        },
    }
end

function FontPreviewItem:setSelected(selected)
    selected = self.entry ~= nil and selected == true
    if self.selected == selected then
        return false
    end
    self.selected = selected
    self.mark_widget:setText(self.entry and (self.selected and "◉" or "○") or "")
    return true
end

function FontPreviewItem:setEntry(entry, selected)
    local entry_changed = self.entry ~= entry
    self.entry = entry
    local selection_changed = self:setSelected(selected)
    if entry_changed and not selection_changed then
        self.mark_widget:setText(entry and (self.selected and "◉" or "○") or "")
    end
    self.text_widget.text = entry and entry.text or ""
    self.text_widget.face = entry and entry.font_filename
        and Font:getFace(entry.font_filename, self.font_size, entry.font_faceindex)
        or Font:getFace("smallinfofont", self.font_size)
    self.text_widget:free()
end

function FontPreviewItem:onTapSelectFont()
    if not self.entry then
        return true
    end
    local callback = self.callback
    local entry = self.entry
    UIManager:nextTick(function()
        callback(entry)
    end)
    return true
end

local function newSliderControl(options)
    local control = {
        callback = options.callback,
        maximum = options.maximum,
        minimum = options.minimum,
        show_parent = options.show_parent,
        step = options.step,
        value_formatter = options.value_formatter or formatRawValue,
        value = clamp(options.value or options.minimum, options.minimum, options.maximum),
    }

    local function updateVisual()
        local percentage = (control.value - control.minimum) / (control.maximum - control.minimum)
        control.progress:setPercentage(percentage)
        control.value_widget:setText(control.value_formatter(control.value))
        if control.progress.dimen then
            UIManager:setDirty(control.show_parent, function()
                return "fast", Geom:new{
                    x = control.progress.dimen.x,
                    y = control.progress.dimen.y - control.value_height - options.value_gap,
                    w = control.progress.dimen.w,
                    h = control.progress.dimen.h + control.value_height + options.value_gap,
                }
            end)
        end
    end

    local function setValue(value, apply)
        value = roundToStep(clamp(value, control.minimum, control.maximum), control.minimum, control.step)
        value = clamp(value, control.minimum, control.maximum)
        control.value = value
        updateVisual()
        if apply then
            control.callback(value)
        end
    end

    local minus_button = Button:new{
        text = "−",
        width = options.button_width,
        height = options.row_height,
        bordersize = 0,
        padding_h = 0,
        padding_v = 0,
        text_font_face = "cfont",
        text_font_size = 22,
        show_parent = options.show_parent,
        callback = function()
            setValue(control.value - control.step, true)
        end,
    }
    control.progress = ProgressWidget:new{
        width = options.progress_width,
        height = Screen:scaleBySize(18),
        percentage = (control.value - control.minimum) / (control.maximum - control.minimum),
        fillcolor = Blitbuffer.COLOR_DARK_GRAY,
    }
    local plus_button = Button:new{
        text = "＋",
        width = options.button_width,
        height = options.row_height,
        bordersize = 0,
        padding_h = 0,
        padding_v = 0,
        text_font_face = "cfont",
        text_font_size = 22,
        show_parent = options.show_parent,
        callback = function()
            setValue(control.value + control.step, true)
        end,
    }
    local label_widget = TextWidget:new{
        text = options.label,
        face = Font:getFace("cfont", 17),
    }
    local label_container = LeftContainer:new{
        dimen = Geom:new{ w = options.label_width, h = options.row_height },
        label_widget,
    }
    control.value_widget = TextWidget:new{
        text = control.value_formatter(control.value),
        face = getPrimaryValueFace(16),
    }
    control.value_height = control.value_widget:getSize().h
    local slider_row = HorizontalGroup:new{
        allow_mirroring = false,
        align = "center",
        label_container,
        HorizontalSpan:new{ width = options.gap },
        minus_button,
        HorizontalSpan:new{ width = options.gap },
        control.progress,
        HorizontalSpan:new{ width = options.gap },
        plus_button,
    }
    local value_row = HorizontalGroup:new{
        allow_mirroring = false,
        HorizontalSpan:new{
            width = options.label_width + 2 * options.gap + options.button_width,
        },
        CenterContainer:new{
            dimen = Geom:new{ w = options.progress_width, h = control.value_height },
            control.value_widget,
        },
    }
    local progress_height = control.progress:getSize().h
    value_row.overlap_offset = {
        0,
        math.floor((options.row_height - progress_height) / 2)
            - options.value_gap - control.value_height,
    }
    control.widget = OverlapGroup:new{
        allow_mirroring = false,
        dimen = Geom:new{ w = slider_row:getSize().w, h = options.row_height },
        slider_row,
        value_row,
    }
    control.setFromPosition = function(pos, apply)
        if not control.progress.dimen then
            return false
        end
        local dimen = control.progress.dimen
        local percentage = clamp((pos.x - dimen.x) / dimen.w, 0, 1)
        setValue(control.minimum + percentage * (control.maximum - control.minimum), apply)
        return true
    end
    control.setValue = setValue
    return control
end

local TypographyOverlay = InputContainer:extend{
    covers_footer = true,
    stop_events_propagation = true,
}

function TypographyOverlay.installCommonAlignmentTweaks(ui, apply)
    local style_tweak = ui and ui.styletweak
    if not style_tweak or not style_tweak.tweaks_by_id then
        return
    end

    local active_tweak_changed = false
    for tweak_id, css in pairs(COMMON_ALIGNMENT_CSS) do
        local tweak = style_tweak.tweaks_by_id[tweak_id]
        if tweak and tweak.css ~= css then
            tweak.css = css
            if style_tweak:isTweakEnabled(tweak_id) then
                active_tweak_changed = true
            end
        end
    end
    if apply and active_tweak_changed then
        style_tweak:updateCssText(true)
    end
end

function TypographyOverlay:getFontEntries()
    local font = self.plugin.ui.font
    local FontList = require("fontlist")
    local cre = require("document/credocument"):engineInit()
    font:setupFaceMenuTable()
    local entries = {}
    for _, entry in ipairs(font.face_table) do
        if entry.menu_item_id and entry.callback then
            local face = entry.menu_item_id
            local font_filename, font_faceindex = cre.getFontFaceFilenameAndFaceIndex(face)
            if not font_filename then
                font_filename, font_faceindex = cre.getFontFaceFilenameAndFaceIndex(face, nil, true)
            end
            table.insert(entries, {
                callback = entry.callback,
                font_faceindex = font_faceindex,
                font_filename = font_filename,
                menu_item_id = face,
                text = font_filename and font_faceindex
                    and (FontList:getLocalizedFontName(font_filename, font_faceindex) or face)
                    or face,
            })
        end
    end
    return entries
end

function TypographyOverlay:expandFontPicker()
    self.plugin:replaceTypographyOverlay{
        font_picker_expanded = true,
    }
end

function TypographyOverlay:changeFontPage(page)
    page = clamp(page, 1, self.font_page_count)
    if page == self.font_page then
        return
    end

    local first_index = (page - 1) * self.fonts_per_page + 1
    local selected_face = self.plugin.ui.font.font_face
    for slot, preview_item in ipairs(self.font_preview_items) do
        local entry = self.font_entries[first_index + slot - 1]
        preview_item:setEntry(entry, entry and entry.menu_item_id == selected_face)
    end
    self.font_page = page
    self.font_page_label:setText(string.format("%d / %d", page, self.font_page_count))
    self.font_previous_button.image.dim = page == 1
    self.font_next_button.image.dim = page == self.font_page_count

    UIManager:setDirty(self, function()
        return "ui", self.font_preview_group.dimen
    end)
end

function TypographyOverlay:selectPreviewFont(entry)
    self:applyTypographyChange(entry.callback)
    for _, preview_item in ipairs(self.font_preview_items) do
        if preview_item:setSelected(preview_item.entry
                and preview_item.entry.menu_item_id == entry.menu_item_id)
                and preview_item.dimen then
            local item_dimen = preview_item.dimen
            UIManager:setDirty(self, function()
                return "ui", item_dimen
            end)
        end
    end
    local face = entry.font_filename
        and Font:getFace(entry.font_filename, 19, entry.font_faceindex)
        or getPrimaryValueFace(19)
    self.font_name_button:setFont(self.plugin.ui.font.font_face, face)
    self.font_value_group:resetLayout()
    self:refreshUseDefaultsEmphasis()
    UIManager:setDirty(self, function()
        return "ui", self.font_value.dimen or self.panel.dimen
    end)
end

function TypographyOverlay:collapseFontPicker()
    self.plugin:replaceTypographyOverlay{}
end

function TypographyOverlay:applyTypographyChange(callback)
    -- ReaderRolling intentionally owns the stable xpointer used across a
    -- document rerender.  Recomputing it from screen coordinates here can
    -- select a nearby DOM node (especially at chapter boundaries) and make a
    -- typography change appear to turn a page.  Match KOReader's native
    -- controls: leave the saved xpointer untouched and only request reflow.
    callback()
end

function TypographyOverlay:scheduleTypographyChange(callback)
    UIManager:nextTick(function()
        if self.plugin.ui and self.plugin.ui.document then
            self:applyTypographyChange(callback)
        end
    end)
end

function TypographyOverlay:init()
    self.installCommonAlignmentTweaks(self.plugin.ui, false)
    self.font_picker_expanded = self.font_picker_expanded == true
    self.font_preview_items = {}
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    local top_offset = self.top_offset or 0
    local horizontal_padding = Size.padding.large
    local content_width = screen_width - 2 * horizontal_padding
    local row_height = Size.item.height_big
    local action_height = Size.item.height_big
    local label_width = Screen:scaleBySize(130)
    local slider_button_width = Screen:scaleBySize(46)
    local slider_gap = Screen:scaleBySize(8)
    local slider_value_gap = Screen:scaleBySize(1)
    local row_gap = Screen:scaleBySize(10)
    local expanded_value_gap = Screen:scaleBySize(8)
    local content_padding_top = Screen:scaleBySize(16)
    local content_padding_bottom = Screen:scaleBySize(18)
    local progress_width = content_width
        - label_width
        - 2 * slider_button_width
        - 3 * slider_gap

    self.dimen = Geom:new{
        x = 0,
        y = 0,
        w = screen_width,
        h = screen_height,
    }
    self.slider_controls = {}

    local font_preview_group
    if self.font_picker_expanded then
        local font_entries = self:getFontEntries()
        local font_columns = 2
        local component_border = Size.border.thin
        local component_padding = Size.padding.small
        local preview_reserve = math.max(
            math.floor(screen_height * 0.25),
            Screen:scaleBySize(220)
        )
        local base_panel_height = 6 * row_height
            + 4 * row_gap
            + expanded_value_gap
            + content_padding_top
            + content_padding_bottom
            + Size.line.medium
        local fixed_expanded_height = base_panel_height
            + row_gap
            + expanded_value_gap
            + row_height
            + 2 * (component_border + component_padding)
        local available_rows_height = screen_height
            - top_offset
            - preview_reserve
            - fixed_expanded_height
        local font_rows = clamp(math.floor(available_rows_height / row_height), 1, 4)
        local fonts_per_page = font_columns * font_rows
        local page_count = math.max(1, math.ceil(#font_entries / fonts_per_page))
        self.font_entries = font_entries
        self.fonts_per_page = fonts_per_page
        self.font_page_count = page_count
        if not self.font_page then
            self.font_page = 1
            for index, entry in ipairs(font_entries) do
                if entry.menu_item_id == self.plugin.ui.font.font_face then
                    self.font_page = math.floor((index - 1) / fonts_per_page) + 1
                    break
                end
            end
        end
        self.font_page = clamp(self.font_page, 1, page_count)

        local component_inner_width = content_width
            - 2 * component_border - 2 * component_padding
        local pager_icon_size = Screen:scaleBySize(18)
        local pager_button_width = Screen:scaleBySize(42)
        local page_label_width = Screen:scaleBySize(80)
        local previous_button = IconButton:new{
            icon = "chevron.left",
            width = pager_icon_size,
            height = pager_icon_size,
            padding_left = math.floor((pager_button_width - pager_icon_size) / 2),
            padding_right = math.ceil((pager_button_width - pager_icon_size) / 2),
            allow_flash = false,
            show_parent = self,
            callback = function() self:changeFontPage(self.font_page - 1) end,
        }
        local next_button = IconButton:new{
            icon = "chevron.right",
            width = pager_icon_size,
            height = pager_icon_size,
            padding_left = math.floor((pager_button_width - pager_icon_size) / 2),
            padding_right = math.ceil((pager_button_width - pager_icon_size) / 2),
            allow_flash = false,
            show_parent = self,
            callback = function() self:changeFontPage(self.font_page + 1) end,
        }
        previous_button.image.dim = self.font_page == 1
        next_button.image.dim = self.font_page == page_count
        self.font_previous_button = previous_button
        self.font_next_button = next_button
        self.font_page_label = TextWidget:new{
            text = string.format("%d / %d", self.font_page, page_count),
            face = Font:getFace("smallinfofont", 15),
        }
        local pager = CenterContainer:new{
            dimen = Geom:new{ w = component_inner_width, h = row_height },
            HorizontalGroup:new{
                allow_mirroring = false,
                CenterContainer:new{
                    dimen = Geom:new{ w = pager_button_width, h = row_height },
                    previous_button,
                },
                CenterContainer:new{
                    dimen = Geom:new{ w = page_label_width, h = row_height },
                    self.font_page_label,
                },
                CenterContainer:new{
                    dimen = Geom:new{ w = pager_button_width, h = row_height },
                    next_button,
                },
            },
        }
        local preview_children = { pager }
        local column_gap = Screen:scaleBySize(4)
        local preview_item_width = math.floor((component_inner_width - column_gap) / 2)
        local first_index = (self.font_page - 1) * fonts_per_page + 1
        for row = 1, font_rows do
            local row_group = HorizontalGroup:new{
                allow_mirroring = false,
            }
            for column = 1, font_columns do
                local index = first_index + (row - 1) * font_columns + column - 1
                local entry = font_entries[index]
                local preview_item = FontPreviewItem:new{
                    callback = function(item) self:selectPreviewFont(item) end,
                    entry = entry,
                    font_size = 18,
                    height = row_height,
                    selected = entry and entry.menu_item_id == self.plugin.ui.font.font_face,
                    width = preview_item_width,
                }
                table.insert(self.font_preview_items, preview_item)
                table.insert(row_group, preview_item)
                if column < font_columns then
                    table.insert(row_group, HorizontalSpan:new{ width = column_gap })
                end
            end
            table.insert(preview_children, row_group)
        end
        font_preview_group = FrameContainer:new{
            width = content_width,
            bordersize = component_border,
            padding = component_padding,
            radius = Screen:scaleBySize(3),
            background = Blitbuffer.COLOR_WHITE,
            VerticalGroup:new(preview_children),
        }
    end

    local function toggleFontPicker()
        if self.font_picker_expanded then
            self:collapseFontPicker()
        else
            self:expandFontPicker()
        end
    end
    local font_label = Button:new{
        text = _("Font"),
        width = label_width,
        height = row_height,
        align = "left",
        bordersize = 0,
        padding_h = 0,
        padding_v = 0,
        text_font_bold = false,
        text_font_face = "cfont",
        text_font_size = 18,
        show_parent = self,
        callback = toggleFontPicker,
    }
    local font_icon_size = Screen:scaleBySize(18)
    local font_chevron_width = font_icon_size + 2 * Size.padding.small
    local font_name_button = FontNameButton:new{
        text = self.plugin.ui.font.font_face,
        face = getDocumentFontFace(self.plugin.ui, 19),
        height = row_height,
        max_width = content_width - label_width - font_chevron_width,
        callback = toggleFontPicker,
    }
    self.font_name_button = font_name_button
    local font_chevron = IconButton:new{
        icon = self.font_picker_expanded and "chevron.up" or "chevron.right",
        icon_rotation_angle = self.font_picker_expanded and 180 or 0,
        width = font_icon_size,
        height = font_icon_size,
        padding = Size.padding.small,
        allow_flash = false,
        show_parent = self,
        callback = toggleFontPicker,
    }
    local font_chevron_container = OpticalCenterContainer:new{
        dimen = Geom:new{ w = font_chevron_width, h = row_height },
        y_offset = self.font_picker_expanded and 0 or -Screen:scaleBySize(3),
        font_chevron,
    }
    local font_value_group = HorizontalGroup:new{
        font_name_button,
        font_chevron_container,
    }
    self.font_value_group = font_value_group
    local font_value = RightContainer:new{
        dimen = Geom:new{ w = content_width - label_width, h = row_height },
        font_value_group,
    }
    local font_row = HorizontalGroup:new{
        allow_mirroring = false,
        font_label,
        font_value,
    }
    self.font_row = font_row
    self.font_value = font_value
    self.font_preview_group = font_preview_group

    local configurable = self.plugin.ui.document.configurable
    local margin_values = configurable.h_page_margins or { 10, 10 }
    local shared_margin = Math.round((margin_values[1] + margin_values[2]) / 2)
    local slider_options = {
        button_width = slider_button_width,
        gap = slider_gap,
        label_width = label_width,
        progress_width = progress_width,
        row_height = row_height,
        show_parent = self,
        value_gap = slider_value_gap,
    }

    local font_size_slider = newSliderControl{
        button_width = slider_options.button_width,
        callback = function(value)
            self:scheduleTypographyChange(function() self:applyFontSize(value) end)
        end,
        gap = slider_options.gap,
        label = _("Font Size"),
        label_width = slider_options.label_width,
        maximum = 44,
        minimum = 12,
        progress_width = slider_options.progress_width,
        row_height = slider_options.row_height,
        show_parent = self,
        step = 0.5,
        value_gap = slider_options.value_gap,
        value = configurable.font_size,
    }
    local line_spacing_slider = newSliderControl{
        button_width = slider_options.button_width,
        callback = function(value)
            self:scheduleTypographyChange(function() self:applyLineSpacing(value) end)
        end,
        gap = slider_options.gap,
        label = _("Line Spacing"),
        label_width = slider_options.label_width,
        maximum = 130,
        minimum = 70,
        progress_width = slider_options.progress_width,
        row_height = slider_options.row_height,
        show_parent = self,
        step = 5,
        value_gap = slider_options.value_gap,
        value_formatter = function(value) return string.format("%.2f", value / 100) end,
        value = configurable.line_spacing,
    }
    local margins_slider = newSliderControl{
        button_width = slider_options.button_width,
        callback = function(value)
            self:scheduleTypographyChange(function() self:applyMargins(value) end)
        end,
        gap = slider_options.gap,
        label = _("L/R Margins"),
        label_width = slider_options.label_width,
        maximum = 140,
        minimum = 0,
        progress_width = slider_options.progress_width,
        row_height = slider_options.row_height,
        show_parent = self,
        step = 5,
        value_gap = slider_options.value_gap,
        value = shared_margin,
    }
    self.slider_controls = {
        font_size_slider,
        line_spacing_slider,
        margins_slider,
    }

    local alignment_label = LeftContainer:new{
        dimen = Geom:new{ w = label_width, h = row_height },
        TextWidget:new{
            text = _("Text Alignment"),
            face = Font:getFace("cfont", 17),
        },
    }
    local alignment_width = content_width - label_width - slider_gap
    local alignment_gap = Screen:scaleBySize(4)
    local alignment_button_width = math.floor((alignment_width - 2 * alignment_gap) / 3)
    self.alignment_buttons = {}
    local alignment_group = HorizontalGroup:new{
        allow_mirroring = false,
        alignment_label,
        HorizontalSpan:new{ width = slider_gap },
    }
    local alignment_items = {
        { mode = "auto", text = C_("Alignment", "publisher") },
        { mode = "left", text = C_("Alignment", "left") },
        { mode = "justify", text = C_("Alignment", "justify") },
    }
    self.alignment_mode = self:getAlignmentMode()
    for index, item in ipairs(alignment_items) do
        local mode = item.mode
        local button = Button:new{
            text = item.text,
            width = alignment_button_width,
            height = row_height,
            bordersize = Size.border.thin,
            padding_h = 0,
            padding_v = 0,
            text_font_face = "cfont",
            text_font_size = 16,
            text_font_bold = false,
            preselect = mode == self.alignment_mode,
            show_parent = self,
            callback = function()
                self:scheduleTypographyChange(function() self:setAlignmentMode(mode) end)
            end,
        }
        self.alignment_buttons[mode] = button
        table.insert(alignment_group, button)
        if index < #alignment_items then
            table.insert(alignment_group, HorizontalSpan:new{ width = alignment_gap })
        end
    end

    local action_gap = Screen:scaleBySize(10)
    local action_button_width = math.floor((content_width - action_gap) / 2)
    local use_defaults_button = Button:new{
        text = _("Use defaults"),
        width = action_button_width,
        height = action_height,
        bordersize = Size.border.thin,
        padding_h = Screen:scaleBySize(4),
        padding_v = 0,
        text_font_face = "cfont",
        text_font_size = 17,
        text_font_bold = not self:settingsMatchDefaults(),
        show_parent = self,
        callback = function()
            self:applyDefaults()
        end,
    }
    self.use_defaults_button = use_defaults_button
    local set_defaults_button = Button:new{
        text = _("Set as defaults"),
        width = action_button_width,
        height = action_height,
        bordersize = Size.border.thin,
        padding_h = Screen:scaleBySize(4),
        padding_v = 0,
        text_font_face = "cfont",
        text_font_size = 17,
        show_parent = self,
        callback = function()
            self:confirmSaveDefaults()
        end,
    }
    local action_group = HorizontalGroup:new{
        allow_mirroring = false,
        use_defaults_button,
        HorizontalSpan:new{ width = action_gap },
        set_defaults_button,
    }

    local content_children = { font_row }
    if font_preview_group then
        table.insert(content_children, VerticalSpan:new{ width = row_gap })
        table.insert(content_children, font_preview_group)
    end
    local font_size_gap = font_preview_group
        and row_gap + expanded_value_gap
        or row_gap
    table.insert(content_children, VerticalSpan:new{ width = font_size_gap })
    table.insert(content_children, font_size_slider.widget)
    table.insert(content_children, VerticalSpan:new{ width = row_gap })
    table.insert(content_children, line_spacing_slider.widget)
    table.insert(content_children, VerticalSpan:new{ width = row_gap })
    table.insert(content_children, margins_slider.widget)
    table.insert(content_children, VerticalSpan:new{ width = row_gap })
    table.insert(content_children, alignment_group)
    table.insert(content_children, VerticalSpan:new{ width = Screen:scaleBySize(8) })
    table.insert(content_children, action_group)
    local content_group = VerticalGroup:new(content_children)
    local content_frame = FrameContainer:new{
        width = screen_width,
        bordersize = 0,
        padding = 0,
        padding_left = horizontal_padding,
        padding_right = horizontal_padding,
        padding_top = content_padding_top,
        padding_bottom = content_padding_bottom,
        background = Blitbuffer.COLOR_WHITE,
        content_group,
    }
    self.panel = FrameContainer:new{
        width = screen_width,
        bordersize = 0,
        padding = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            content_frame,
            LineWidget:new{
                background = Blitbuffer.COLOR_BLACK,
                dimen = Geom:new{ w = screen_width, h = Size.line.medium },
            },
        },
    }
    self[1] = TopContainer:new{
        dimen = self.dimen:copy(),
        VerticalGroup:new{
            VerticalSpan:new{ width = top_offset },
            self.panel,
        },
    }

    local full_screen_range = Geom:new{
        x = 0,
        y = 0,
        w = screen_width,
        h = screen_height,
    }
    self.ges_events = {
        TapTypography = {
            GestureRange:new{ ges = "tap", range = full_screen_range },
        },
        PanTypography = {
            GestureRange:new{ ges = "pan", range = full_screen_range },
        },
        PanReleaseTypography = {
            GestureRange:new{ ges = "pan_release", range = full_screen_range },
        },
        SwipeTypography = {
            GestureRange:new{ ges = "swipe", range = full_screen_range },
        },
    }
end

function TypographyOverlay:applyFontSize(value, refresh_emphasis)
    local ui = self.plugin.ui
    ui.font.configurable.font_size = value
    ui.document:setFontSize(Screen:scaleBySize(value))
    ui:handleEvent(Event:new("UpdatePos"))
    if refresh_emphasis ~= false then
        self:refreshUseDefaultsEmphasis()
    end
end

function TypographyOverlay:applyLineSpacing(value, refresh_emphasis)
    local ui = self.plugin.ui
    ui.font.configurable.line_spacing = value
    ui.document:setInterlineSpacePercent(value)
    ui:handleEvent(Event:new("UpdatePos"))
    if refresh_emphasis ~= false then
        self:refreshUseDefaultsEmphasis()
    end
end

function TypographyOverlay:applyMargins(value, refresh_emphasis)
    local margins = { value, value }
    self.plugin.ui.document.configurable.h_page_margins = margins
    self.plugin.ui.typeset.configurable.h_page_margins = margins
    self.plugin.ui.typeset:onSetPageHorizMargins(margins)
    if refresh_emphasis ~= false then
        self:refreshUseDefaultsEmphasis()
    end
end

function TypographyOverlay:getDefaultAlignmentMode()
    local style_tweak = self.plugin.ui.styletweak
    local global_tweaks = style_tweak and style_tweak.global_tweaks or {}
    if global_tweaks.text_align_most_left or global_tweaks.text_align_all_left then
        return "left"
    end
    if global_tweaks.text_align_most_justify or global_tweaks.text_align_all_justify then
        return "justify"
    end
    return "auto"
end

function TypographyOverlay:settingsMatchDefaults()
    local ui = self.plugin.ui
    local configurable = ui.document.configurable
    local default_font = G_reader_settings:readSetting("cre_font")
        or ui.document.default_font
    local default_size = G_reader_settings:readSetting("copt_font_size")
        or configurable.font_size
    local default_spacing = G_reader_settings:readSetting("copt_line_spacing")
        or configurable.line_spacing
    local default_margins = G_reader_settings:readSetting("copt_h_page_margins")
        or configurable.h_page_margins
    local current_margins = configurable.h_page_margins

    return ui.font.font_face == default_font
        and valuesMatch(configurable.font_size, default_size)
        and valuesMatch(configurable.line_spacing, default_spacing)
        and type(current_margins) == "table"
        and type(default_margins) == "table"
        and valuesMatch(current_margins[1], default_margins[1])
        and valuesMatch(current_margins[2], default_margins[2])
        and self:getAlignmentMode() == self:getDefaultAlignmentMode()
end

function TypographyOverlay:refreshUseDefaultsEmphasis()
    local button = self.use_defaults_button
    if not button or not button.label_widget then
        return
    end
    local bold = not self:settingsMatchDefaults()
    if button.label_widget.bold == bold then
        return
    end
    button.text_font_bold = bold
    button.label_widget.bold = bold
    button.label_widget:free()
    UIManager:setDirty(self, function()
        return "ui", button.dimen or self.panel.dimen
    end)
end

function TypographyOverlay:getAlignmentMode()
    local style_tweak = self.plugin.ui.styletweak
    if not style_tweak or not style_tweak.enabled then
        return "auto"
    end
    if style_tweak:isTweakEnabled("text_align_most_left")
            or style_tweak:isTweakEnabled("text_align_all_left") then
        return "left"
    end
    if style_tweak:isTweakEnabled("text_align_most_justify")
            or style_tweak:isTweakEnabled("text_align_all_justify") then
        return "justify"
    end
    return "auto"
end

function TypographyOverlay:setAlignmentMode(mode)
    local style_tweak = self.plugin.ui.styletweak
    if not style_tweak or mode == self.alignment_mode then
        return
    end
    style_tweak.enabled = true
    local desired_id = mode == "left" and "text_align_most_left"
        or mode == "justify" and "text_align_most_justify"
        or nil

    -- Make this three-state control authoritative over all KOReader left and
    -- justify variants. A false document value is required to override a
    -- globally enabled tweak for the current book.
    for _, tweak_id in ipairs(ALIGNMENT_TWEAKS) do
        if tweak_id == desired_id then
            if style_tweak.global_tweaks[tweak_id] then
                style_tweak.doc_tweaks[tweak_id] = nil
            else
                style_tweak.doc_tweaks[tweak_id] = true
            end
        elseif style_tweak.global_tweaks[tweak_id] then
            style_tweak.doc_tweaks[tweak_id] = false
        else
            style_tweak.doc_tweaks[tweak_id] = nil
        end
    end
    style_tweak:updateCssText(true)
    self.alignment_mode = mode
    for button_mode, button in pairs(self.alignment_buttons) do
        local selected = button_mode == mode
        if (button.frame.invert == true) ~= selected then
            button.frame.invert = selected
            if button.dimen then
                local button_dimen = button.dimen
                UIManager:setDirty(self, function()
                    return "ui", button_dimen
                end)
            end
        end
    end
    self:refreshUseDefaultsEmphasis()
end

function TypographyOverlay:confirmSaveDefaults()
    UIManager:show(ConfirmBox:new{
        text = _("Use these typography settings as default values?"),
        ok_text = _("Save"),
        ok_callback = function()
            self:saveDefaults()
        end,
    })
end

function TypographyOverlay:applyDefaults()
    local ui = self.plugin.ui
    local configurable = ui.document.configurable
    local font_face = G_reader_settings:readSetting("cre_font")
        or ui.document.default_font
    local font_size = G_reader_settings:readSetting("copt_font_size")
        or configurable.font_size
    local line_spacing = G_reader_settings:readSetting("copt_line_spacing")
        or configurable.line_spacing
    local margins = G_reader_settings:readSetting("copt_h_page_margins")
        or configurable.h_page_margins

    if ui.font.font_face ~= font_face then
        ui.font:onSetFont(font_face)
    end
    if not valuesMatch(configurable.font_size, font_size) then
        self:applyFontSize(font_size, false)
    end
    if not valuesMatch(configurable.line_spacing, line_spacing) then
        self:applyLineSpacing(line_spacing, false)
    end
    if type(margins) == "table" and margins[1] and margins[2] then
        local default_margins = { margins[1], margins[2] }
        local current_margins = configurable.h_page_margins
        if type(current_margins) ~= "table"
                or not valuesMatch(current_margins[1], default_margins[1])
                or not valuesMatch(current_margins[2], default_margins[2]) then
            ui.document.configurable.h_page_margins = default_margins
            ui.typeset.configurable.h_page_margins = default_margins
            ui.typeset:onSetPageHorizMargins(default_margins)
        end
    end

    local style_tweak = ui.styletweak
    if style_tweak then
        for _, tweak_id in ipairs(ALIGNMENT_TWEAKS) do
            style_tweak.doc_tweaks[tweak_id] = nil
        end
        style_tweak:updateCssText(true)
    end

    self.slider_controls[1].setValue(font_size, false)
    self.slider_controls[2].setValue(line_spacing, false)
    if type(margins) == "table" and margins[1] and margins[2] then
        self.slider_controls[3].setValue(Math.round((margins[1] + margins[2]) / 2), false)
    end

    for _, preview_item in ipairs(self.font_preview_items) do
        if preview_item:setSelected(preview_item.entry
                and preview_item.entry.menu_item_id == ui.font.font_face)
                and preview_item.dimen then
            local item_dimen = preview_item.dimen
            UIManager:setDirty(self, function()
                return "ui", item_dimen
            end)
        end
    end
    self.font_name_button:setFont(ui.font.font_face, getDocumentFontFace(ui, 19))
    self.font_value_group:resetLayout()
    UIManager:setDirty(self, function()
        return "ui", self.font_value.dimen or self.panel.dimen
    end)

    self.alignment_mode = self:getAlignmentMode()
    for button_mode, button in pairs(self.alignment_buttons) do
        local selected = button_mode == self.alignment_mode
        if (button.frame.invert == true) ~= selected then
            button.frame.invert = selected
            if button.dimen then
                local button_dimen = button.dimen
                UIManager:setDirty(self, function()
                    return "ui", button_dimen
                end)
            end
        end
    end
    self:refreshUseDefaultsEmphasis()

    UIManager:show(Notification:new{
        text = _("Default settings applied"),
    })
end

function TypographyOverlay:saveDefaults()
    local ui = self.plugin.ui
    local configurable = ui.document.configurable
    G_reader_settings:saveSetting("cre_font", ui.font.font_face)
    G_reader_settings:saveSetting("copt_font_size", configurable.font_size)
    G_reader_settings:saveSetting("copt_line_spacing", configurable.line_spacing)
    G_reader_settings:saveSetting("copt_h_page_margins", configurable.h_page_margins)

    local style_tweak = ui.styletweak
    if style_tweak then
        local desired_id = self.alignment_mode == "left" and "text_align_most_left"
            or self.alignment_mode == "justify" and "text_align_most_justify"
            or nil
        for _, tweak_id in ipairs(ALIGNMENT_TWEAKS) do
            style_tweak.global_tweaks[tweak_id] = tweak_id == desired_id and true or nil
            style_tweak.doc_tweaks[tweak_id] = nil
        end
        G_reader_settings:saveSetting("style_tweaks", style_tweak.global_tweaks)
        style_tweak:updateCssText(true)
    end
    UIManager:show(Notification:new{
        text = _("Default settings updated"),
    })
    self:refreshUseDefaultsEmphasis()
end

function TypographyOverlay:findSliderAt(pos)
    for _, control in ipairs(self.slider_controls) do
        if control.progress.dimen and pos:intersectWith(control.progress.dimen) then
            return control
        end
    end
end

function TypographyOverlay:onTapTypography(_, ges)
    local control = self:findSliderAt(ges.pos)
    if control then
        control.setFromPosition(ges.pos, true)
    elseif ges.pos.y < (self.top_offset or 0)
            and self.plugin:switchToolbarAction(ges.pos, "typography") then
        return true
    elseif self.panel.dimen and ges.pos:notIntersectWith(self.panel.dimen) then
        self.plugin:closeTypographyOverlay()
    end
    return true
end

function TypographyOverlay:onPanTypography(_, ges)
    if not self.active_slider then
        self.active_slider = self:findSliderAt(ges.pos)
    end
    if self.active_slider then
        self.active_slider.setFromPosition(ges.pos, false)
    end
    return true
end

function TypographyOverlay:onPanReleaseTypography(_, ges)
    if self.active_slider then
        self.active_slider.setFromPosition(ges.pos, true)
        self.active_slider = nil
    end
    return true
end

function TypographyOverlay:onSwipeTypography(_, ges)
    local control = self:findSliderAt(ges.pos)
    if ges.direction == "south" then
        self.plugin:closeTypographyOverlay()
    elseif control and ges.end_pos
            and (ges.direction == "east" or ges.direction == "west") then
        control.setFromPosition(ges.end_pos, true)
    end
    return true
end

function TypographyOverlay:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.panel.dimen
    end)
    return true
end

function TypographyOverlay:onCloseWidget()
    local toolbar = self.plugin.overlay
    if toolbar and toolbar.selected_action == "typography" then
        toolbar:setSelectedAction(nil)
    end
    if self.plugin.typography_overlay == self then
        self.plugin.typography_overlay = nil
    end
    UIManager:setDirty(nil, function()
        return "flashui", self.panel.dimen
    end)
end

function TypographyOverlay:onClose()
    self.plugin:closeTypographyOverlay()
    return true
end

return TypographyOverlay
