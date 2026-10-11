-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local ReturnStyle = require("modules.shared.return_style")
local Screen = require("device").screen
local TextWidget = require("ui/widget/textwidget")
local T = require("ffi/util").template
local _ = require("gettext")

local ReturnFooter = InputContainer:extend{
    name = "plainui_return_footer",
}

function ReturnFooter:init()
    self.padding = ReturnStyle.padding
    self.line_height = Screen:scaleBySize(1)
    self.dimen = Geom:new{
        x = 0, y = Screen:getHeight() - ReturnStyle.height,
        w = Screen:getWidth(), h = ReturnStyle.height,
    }
    self.ges_events = {
        TapPlainReturnFooter = { GestureRange:new{ ges = "tap", range = self.dimen } },
        -- Gestures inside the footer must not also turn a page or open a menu.
        IgnorePlainReturnFooter = {
            GestureRange:new{ ges = "hold", range = self.dimen },
            GestureRange:new{ ges = "swipe", range = self.dimen },
            GestureRange:new{ ges = "double_tap", range = self.dimen },
        },
    }
    self.labels = {}
end

function ReturnFooter:updateLabels()
    local back, forward = self.history:getDestinations()
    self.back, self.forward = back, forward
    local back_page = self.history:getPageLabel(back)
    local forward_page = self.history:getPageLabel(forward)
    local texts = {
        back and (back_page and "← " .. T(_("Page %1"), back_page) or _("← Back")) or "",
        forward and (forward_page and T(_("Page %1"), forward_page) .. " →" or _("Forward →")) or "",
        _("Stay here"),
    }
    for i, text in ipairs(texts) do
        if not self.labels[i] or self.labels[i].text ~= text then
            if self.labels[i] then self.labels[i]:free() end
            self.labels[i] = TextWidget:new{
                text = text,
                face = Font:getFace("smallinfofont", ReturnStyle.font_size),
                bold = true,
                max_width = math.floor(self.dimen.w / 3) - 2 * self.padding,
            }
        end
    end
end

function ReturnFooter:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    self:updateLabels()
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    bb:paintRect(x, y, self.dimen.w, self.line_height, Blitbuffer.COLOR_DARK_GRAY)
    for i, widget in ipairs(self.labels) do
        local size = widget:getSize()
        local label_x = i == 1 and x + self.padding
            or i == 2 and x + math.floor((self.dimen.w - size.w) / 2)
            or x + self.dimen.w - self.padding - size.w
        local label_y = y + math.floor((self.dimen.h - size.h) / 2)
        widget:paintTo(bb, label_x, label_y)
        if widget.text ~= "" then ReturnStyle.underline(bb, label_x, label_y, size) end
    end
end

function ReturnFooter:onTapPlainReturnFooter(_, ges)
    -- Re-read destinations in case a page turn happened since the last paint.
    local back, forward = self.history:getDestinations()
    local slot = math.floor((ges.pos.x - self.dimen.x) * 3 / self.dimen.w) + 1
    if slot == 1 and back then self.history:goBack()
    elseif slot == 2 and forward then self.history:goForward()
    elseif slot == 3 then self.history:stayHere() end
    return true
end

function ReturnFooter:onIgnorePlainReturnFooter()
    return true
end

function ReturnFooter:onCloseWidget()
    for _, widget in ipairs(self.labels) do widget:free() end
    self.labels = {}
end

return ReturnFooter
