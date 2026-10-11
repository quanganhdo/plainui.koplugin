-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen
local Size = require("ui/size")

local ReturnStyle = {
    font_size = 18,
    height = Size.item.height_big,
    padding = Screen:scaleBySize(24),
}

function ReturnStyle.underline(bb, x, y, size)
    if size.w <= 0 then return end
    local stroke = math.max(1, Screen:scaleBySize(1))
    bb:paintRect(x, y + size.h + stroke, size.w, stroke, Blitbuffer.COLOR_BLACK)
end

return ReturnStyle
