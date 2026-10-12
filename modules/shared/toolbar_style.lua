-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Screen = require("device").screen
local Size = require("ui/size")

return {
    button_width = Screen:scaleBySize(52),
    button_height = Size.item.height_big,
    button_gap = Screen:scaleBySize(4),
    icon_size = Screen:scaleBySize(28),
    padding = Size.padding.large,
}
