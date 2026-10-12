-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Actions = require("modules.reader.more_actions")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local Geom = require("ui/geometry")
local LineWidget = require("ui/widget/linewidget")
local Screen = require("device").screen
local Size = require("ui/size")
local ToolbarStyle = require("modules.shared.toolbar_style")

local MoreMenu = ButtonDialog:extend{
    name = "plainui_reader_more_menu",
    buttons = {},
    info_padding = 0,
    info_margin = 0,
}

function MoreMenu:init()
    self.width = math.min(Screen:scaleBySize(280), Screen:getWidth() - 2 * ToolbarStyle.padding)
    if self.anchor then
        self.anchor.x = math.min(self.anchor.x, Screen:getWidth() - ToolbarStyle.padding - self.width)
        local panel = self.plugin.overlay and self.plugin.overlay.panel
        if panel then
            self.anchor.y = panel.dimen.y + panel:getSize().h + Screen:scaleBySize(4)
            self.anchor.h = 0
        end
    end
    local width = self.width - 2 * Size.border.window - 2 * Size.padding.button
    self.items = Actions.getItems(self.plugin.ui)
    self._added_widgets = {}
    self.buttons_by_key = {}
    local layout = {}
    for _, item in ipairs(self.items) do
        local button = Button:new{
            text = item.text, align = "left",
            width = width, height = ToolbarStyle.button_height,
            bordersize = 0, padding_h = Screen:scaleBySize(16),
            text_font_face = "smallinfofont", text_font_size = 18, text_font_bold = false,
            show_parent = self,
            callback = function() self.plugin:runMoreAction(item.key) end,
        }
        self._added_widgets[#self._added_widgets + 1] = button
        self.buttons_by_key[item.key] = button
        layout[#layout + 1] = { button }
        if item.separator then
            -- ButtonDialog derives divider width from its empty ButtonTable,
            -- so supply the width explicitly for this menu of added widgets.
            self._added_widgets[#self._added_widgets + 1] = LineWidget:new{
                background = Blitbuffer.COLOR_GRAY,
                dimen = Geom:new{ w = width, h = Size.line.medium },
                not_focusable = true,
            }
        end
    end
    ButtonDialog.init(self)
    self.layout = layout
end

function MoreMenu:onCloseWidget()
    if self.plugin.more_menu == self then self.plugin.more_menu = nil end
    self.plugin:setToolbarSelected(nil, "more")
    ButtonDialog.onCloseWidget(self)
end

function MoreMenu:onTapClose(arg, ges)
    if ges.pos:notIntersectWith(self.movable.dimen)
            and self.plugin:switchToolbarAction(ges.pos, "more") then
        return true
    end
    return ButtonDialog.onTapClose(self, arg, ges)
end

return MoreMenu
