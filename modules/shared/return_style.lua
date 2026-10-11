-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Screen = require("device").screen
local Size = require("ui/size")

return {
    font_size = 18,
    height = Size.item.height_big,
    padding = Screen:scaleBySize(24),
}
