-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local CoverBadge = require("modules.cover_badge")
local Device = require("device")
local Font = require("ui/font")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local util = require("util")

local Screen = Device.screen
local CoverOverlay = {}

local function measureText(text, face)
    local widget = TextWidget:new{
        text = text,
        face = face,
        bold = true,
    }
    local width = widget:getSize().w
    widget:free()
    return width
end

local function getLines(text, face, max_width, max_lines)
    text = util.trim(tostring(text or "")):gsub("%s+", " ")
    if text == "" then
        return {}
    end

    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local current = ""
    local i = 1
    while i <= #words and #lines < max_lines do
        local candidate = current == "" and words[i] or current .. " " .. words[i]
        if current == "" or measureText(candidate, face) <= max_width then
            current = candidate
            i = i + 1
        else
            table.insert(lines, current)
            current = ""
            if #lines == max_lines - 1 then
                break
            end
        end
    end

    if #lines < max_lines then
        local rest = current
        while i <= #words do
            rest = rest == "" and words[i] or rest .. " " .. words[i]
            i = i + 1
        end
        if rest ~= "" then
            table.insert(lines, rest)
        end
    end
    return lines
end

function CoverOverlay.paintStackMarks(bb, x, y, w, h)
    local line_w = math.max(3, Size.line.medium)
    local line_h1 = math.floor(h * 0.95)
    local line_h2 = math.floor(h * 0.90)
    local line_gap = Screen:scaleBySize(3)
    local line_x1 = x + w + line_gap
    local line_x2 = line_x1 + line_w + line_gap
    local line_y1 = y + math.floor((h - line_h1) / 2)
    local line_y2 = y + math.floor((h - line_h2) / 2)
    bb:paintRect(line_x1, line_y1, line_w, line_h1, Blitbuffer.COLOR_GRAY_9)
    bb:paintRect(line_x2, line_y2, line_w, line_h2, Blitbuffer.COLOR_GRAY_9)
end

function CoverOverlay.paintTitle(bb, x, y, w, h, border, title)
    if title == nil or title == false then
        return
    end

    border = border or 0
    local padding_h = Screen:scaleBySize(8)
    local padding_v = Screen:scaleBySize(4)
    local overlay_w = math.max(1, w - 2 * border)
    local text_w = math.max(1, overlay_w - 2 * padding_h)
    local face = Font:getFace("cfont", 18)
    local lines = getLines(title, face, text_w, 3)
    if #lines == 0 then
        return
    end

    local widgets = {}
    local max_line_h = 0
    for _, line in ipairs(lines) do
        local widget = TextWidget:new{
            text = line,
            face = face,
            bold = true,
            max_width = text_w,
            fgcolor = Blitbuffer.COLOR_BLACK,
        }
        table.insert(widgets, widget)
        max_line_h = math.max(max_line_h, widget:getSize().h)
    end

    local line_step = max_line_h + Screen:scaleBySize(1)
    local text_h = max_line_h + math.max(0, #widgets - 1) * line_step
    local overlay_h = math.max(1, math.min(h - 2 * border, text_h + 2 * padding_v))
    local overlay_x = x + border
    local overlay_y = y + border + math.floor((h - 2 * border - overlay_h) / 2)
    bb:lightenRect(overlay_x, overlay_y, overlay_w, overlay_h, CoverBadge.LIGHTEN_FACTOR)
    if border > 0 then
        bb:paintRect(overlay_x, overlay_y, overlay_w, border, Blitbuffer.COLOR_BLACK)
        bb:paintRect(overlay_x, overlay_y + overlay_h - border, overlay_w, border, Blitbuffer.COLOR_BLACK)
    end

    local text_y = overlay_y + math.floor((overlay_h - text_h) / 2)
    for _, widget in ipairs(widgets) do
        local size = widget:getSize()
        widget:paintTo(bb, overlay_x + padding_h + math.floor((text_w - size.w) / 2), text_y)
        text_y = text_y + line_step
        widget:free()
    end
end

return CoverOverlay
