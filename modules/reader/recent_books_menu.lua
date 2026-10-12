-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local RecentBooks = require("modules.reader.recent_books")
local Screen = require("device").screen
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local ToolbarStyle = require("modules.shared.toolbar_style")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local RecentBooksMenu = ButtonDialog:extend{
    name = "plainui_reader_recent_books",
    buttons = {}, info_padding = 0, info_margin = 0,
}

function RecentBooksMenu:init()
    self.width = math.min(Screen:scaleBySize(320), Screen:getWidth() - 2 * ToolbarStyle.padding)
    local anchor = self.anchor
    if anchor then
        local point = Geom:new{
            x = ToolbarStyle.padding, y = anchor.y + anchor.h + Screen:scaleBySize(4), w = 0, h = 0,
        }
        self.anchor = function() return point, true end
    end
    local width = self.width - 2 * Size.border.window - 2 * Size.padding.button
    self.books = RecentBooks.get(self.plugin.ui)
    local heading = TextWidget:new{
        text = _("Recent books"), face = Font:getFace("cfont", 18), bold = true,
        max_width = width - 2 * Screen:scaleBySize(16),
    }
    self._added_widgets = {
        FrameContainer:new{
            width = width, bordersize = 0, padding = 0, padding_left = Screen:scaleBySize(16),
            not_focusable = true,
            LeftContainer:new{
                dimen = Geom:new{ w = width - Screen:scaleBySize(16), h = Screen:scaleBySize(36) },
                heading,
            },
        },
    }
    self.book_buttons = {}
    local layout = {}
    local function addButton(text, callback, enabled)
        local button = Button:new{
            text = text, align = "left", width = width, height = ToolbarStyle.button_height,
            bordersize = 0, padding_h = Screen:scaleBySize(16), padding_v = 0,
            text_font_face = "smallinfofont", text_font_size = 18, text_font_bold = false,
            avoid_text_truncation = false,
            enabled = enabled ~= false, show_parent = self, callback = callback,
        }
        -- Keep the selected font size and truncate to one line with an ellipsis.
        button.label_widget.truncate_with_ellipsis = true
        self._added_widgets[#self._added_widgets + 1] = button
        layout[#layout + 1] = { button }
        return button
    end
    for _, book in ipairs(self.books) do
        self.book_buttons[#self.book_buttons + 1] = addButton(book.title, function()
            self.plugin:openRecentBook(book.file)
        end)
    end
    if #self.books == 0 then
        addButton(_("No other recent books"), nil, false)
    end
    self._added_widgets[#self._added_widgets + 1] = LineWidget:new{
        background = Blitbuffer.COLOR_GRAY, dimen = Geom:new{ w = width, h = Size.line.medium },
        not_focusable = true,
    }
    self.history_button = addButton(_("View history"), function() self.plugin:showReadingHistory() end)
    ButtonDialog.init(self)
    self.layout = layout
end

function RecentBooksMenu:onCloseWidget()
    if self.plugin.recent_books_menu == self then self.plugin.recent_books_menu = nil end
    self.plugin:setToolbarSelected(nil, "recent_books")
    ButtonDialog.onCloseWidget(self)
end

function RecentBooksMenu:onTapClose(arg, ges)
    if ges.pos:notIntersectWith(self.movable.dimen) then
        local overlay = self.plugin.overlay
        if overlay and ges.pos:intersectWith(overlay.back_button.dimen) then
            self.plugin:closeRecentBooksMenu()
            UIManager:nextTick(function() self.plugin:backToFileManager() end)
            return true
        end
        if overlay and ges.pos:intersectWith(overlay.menu_hint_dimen) then
            self.plugin:showDefaultMenu()
            return true
        end
        if self.plugin:switchToolbarAction(ges.pos, "recent_books") then return true end
    end
    return ButtonDialog.onTapClose(self, arg, ges)
end

return RecentBooksMenu
