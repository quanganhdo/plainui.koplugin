-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")

local StatusIcon = InputContainer:extend{
    visible = true,
}

function StatusIcon:init()
    self.image = ImageWidget:new{
        file = self.icon_file,
        hide = not self.visible,
        width = self.icon_width,
        height = self.icon_height,
        is_icon = true,
    }
    self.dimen = Geom:new{
        w = self.width,
        h = self.height,
    }
    self[1] = CenterContainer:new{
        dimen = self.dimen,
        self.image,
    }
    if self.callback or self.hold_callback then
        self.ges_events = {
            TapStatusIcon = {
                GestureRange:new{ ges = "tap", range = self.dimen },
            },
            HoldStatusIcon = {
                GestureRange:new{ ges = "hold", range = self.dimen },
            },
            HoldReleaseStatusIcon = {
                GestureRange:new{ ges = "hold_release", range = self.dimen },
            },
        }
    end
end

function StatusIcon:setIcon(icon_file, visible)
    visible = visible ~= false
    local changed = self.icon_file ~= icon_file or self.visible ~= visible
    if not changed then
        return false
    end
    if self.icon_file ~= icon_file then
        self.image:free()
        self.icon_file = icon_file
        self.image.file = icon_file
    end
    self.visible = visible
    self.image.hide = not visible
    return true
end

function StatusIcon:onTapStatusIcon()
    if self.callback then
        self.callback()
        return true
    end
end

function StatusIcon:onHoldStatusIcon()
    if self.hold_callback then
        self.hold_callback()
        self.hold_handled = true
        return true
    end
end

function StatusIcon:onHoldReleaseStatusIcon()
    if self.hold_handled then
        self.hold_handled = nil
        return true
    end
end

return StatusIcon
