-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")

local CoverBadge = {}

CoverBadge.LIGHTEN_FACTOR = 0.60
CoverBadge.FONT_FACE = "infont"
CoverBadge.DEFAULT_FONT_SIZE = 13
CoverBadge.FONT_SIZE_SETTING_KEY = "plainui_badge_font_size"

local LIGHTEN_COLOR = Blitbuffer.Color8A(0xFF, math.floor(0xFF * CoverBadge.LIGHTEN_FACTOR + 0.5))

function CoverBadge.getFontSize()
    if G_reader_settings and G_reader_settings.readSetting then
        local font_size = tonumber(G_reader_settings:readSetting(CoverBadge.FONT_SIZE_SETTING_KEY))
        if font_size and font_size > 0 then
            return font_size
        end
    end
    return CoverBadge.DEFAULT_FONT_SIZE
end

local function lightenRoundedRect(bb, x, y, w, h, radius)
    radius = math.floor(math.min(radius or 0, w / 2, h / 2))
    if radius <= 0 then
        bb:lightenRect(x, y, w, h, CoverBadge.LIGHTEN_FACTOR)
        return
    end

    local r2 = radius * radius
    local left_cx = radius - 0.5
    local right_cx = w - radius - 0.5
    local top_cy = radius - 0.5
    local bottom_cy = h - radius - 0.5
    for dy = 0, h - 1 do
        local cy
        if dy < radius then
            cy = top_cy
        elseif dy >= h - radius then
            cy = bottom_cy
        end
        for dx = 0, w - 1 do
            local cx
            if dx < radius then
                cx = left_cx
            elseif dx >= w - radius then
                cx = right_cx
            end
            if not cx or not cy
                    or (dx + 0.5 - cx) * (dx + 0.5 - cx) + (dy + 0.5 - cy) * (dy + 0.5 - cy) <= r2 then
                bb:setPixelBlend(x + dx, y + dy, LIGHTEN_COLOR)
            end
        end
    end
end

function CoverBadge.newTextBadge(opts)
    local text_widget = TextWidget:new{
        text = opts.text,
        face = opts.face,
        fgcolor = opts.fgcolor or Blitbuffer.COLOR_BLACK,
    }
    local text_size = text_widget:getSize()
    local padding_h = opts.padding_h or opts.padding or 0
    local padding_top = opts.padding_top or opts.padding_v or opts.padding or 0
    local padding_bottom = opts.padding_bottom or opts.padding_v or opts.padding or 0
    local border = opts.border or 0
    local width = opts.width or math.max(
        opts.min_width or 0,
        text_size.w + 2 * padding_h + 2 * border
    )
    local height = opts.height or math.max(
        opts.min_height or 0,
        text_size.h + padding_top + padding_bottom + 2 * border
    )
    local badge = {
        text_widget = text_widget,
        text_size = text_size,
        width = width,
        height = height,
        border = border,
        radius = opts.radius,
        text_y_offset = opts.text_y_offset,
        skip_top_edge = opts.skip_top_edge,
    }
    function badge:getSize()
        return Geom:new{ w = self.width, h = self.height }
    end
    return badge
end

function CoverBadge.paint(bb, x, y, badge)
    local edge_offset = badge.skip_top_edge and (badge.border or 0) or 0
    lightenRoundedRect(bb, x, y + edge_offset, badge.width, badge.height - edge_offset, badge.radius)
    if badge.border and badge.border > 0 then
        if badge.skip_top_edge then
            local border = badge.border
            local border_y = y + border
            local border_h = badge.height - border
            bb:paintRect(x, border_y, border, border_h, Blitbuffer.COLOR_BLACK)
            bb:paintRect(x + badge.width - border, border_y, border, border_h, Blitbuffer.COLOR_BLACK)
            bb:paintRect(x, y + badge.height - border, badge.width, border, Blitbuffer.COLOR_BLACK)
        else
            bb:paintBorder(
                x, y, badge.width, badge.height, badge.border,
                Blitbuffer.COLOR_BLACK, badge.radius,
                G_reader_settings:nilOrTrue("anti_alias_ui")
            )
        end
    end
    local text_x = x + math.floor((badge.width - badge.text_size.w) / 2)
    local text_y = badge.text_y_offset
        and y + badge.text_y_offset
        or y + math.floor((badge.height - badge.text_size.h) / 2)
    badge.text_widget:paintTo(bb, text_x, text_y)
end

return CoverBadge
