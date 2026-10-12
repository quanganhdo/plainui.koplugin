-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen = require("device").screen
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")

local Tab = InputContainer:extend{}
function Tab:init()
    local face = Font:getFace("cfont", 18)
    self.marker = TextWidget:new{ text = "*", face = face, bold = true }
    self.label = TextWidget:new{
        text = self.name, face = face, bold = true,
        max_width = self.width - 2 * Size.padding.small - self.marker:getSize().w,
        truncate_with_ellipsis = true, truncate_left = false,
    }
    self.marker:setText(self.modified and "*" or "")
    self.label_group = HorizontalGroup:new{ allow_mirroring = false, self.label, self.marker }
    self.frame = FrameContainer:new{
        width = self.width, height = self.height, bordersize = 0, padding = 0,
        background = self.selected and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_LIGHT_GRAY,
        CenterContainer:new{ dimen = Geom:new{ w = self.width, h = self.height }, self.label_group },
    }
    self[1], self.dimen = self.frame, Geom:new{ w = self.width, h = self.height }
    self.ges_events = {
        TapProfileTab = { GestureRange:new{ ges = "tap", range = self.dimen } },
        HoldProfileTab = { GestureRange:new{ ges = "hold", range = self.dimen } },
        HoldReleaseProfileTab = { GestureRange:new{ ges = "hold_release", range = self.dimen } },
    }
end

function Tab:paintTo(bb, x, y)
    InputContainer.paintTo(self, bb, x, y)
    local border = Size.border.thin
    bb:paintRect(x, y, self.width, border, Blitbuffer.COLOR_BLACK)
    bb:paintRect(x, y, border, self.height, Blitbuffer.COLOR_BLACK)
    bb:paintRect(x + self.width - border, y, border, self.height, Blitbuffer.COLOR_BLACK)
end

function Tab:update(name, modified, selected)
    self.name, self.modified, self.selected = name, modified, selected
    self.label:setText(name)
    self.marker:setText(modified and "*" or "")
    self.label_group:resetLayout()
    self.frame.background = selected and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_LIGHT_GRAY
end

function Tab:onTapProfileTab()
    UIManager:nextTick(self.callback)
    return true
end
function Tab:onHoldProfileTab()
    self.held = true
    UIManager:nextTick(self.hold_callback)
    return true
end
function Tab:onHoldReleaseProfileTab()
    if self.held then self.held = nil; return true end
end

local Tabs = FrameContainer:extend{}
function Tabs:paintTo(bb, x, y)
    FrameContainer.paintTo(self, bb, x, y)
    local border, height = Size.border.thin, self:getSize().h
    bb:paintRect(x, y + height - border, self.width, border, Blitbuffer.COLOR_BLACK)
    for _, tab in ipairs(self.tabs) do
        if tab.selected then
            bb:paintRect(tab.dimen.x + border, y + height - border,
                tab.width - 2 * border, border, Blitbuffer.COLOR_WHITE)
        end
    end
end

function Tabs.create(profiles, row_height, callback, hold_callback)
    local padding, gap, inset = Size.padding.large, Screen:scaleBySize(4), Screen:scaleBySize(5)
    local width = Screen:getWidth()
    local tab_width = math.floor((width - 2 * padding - 2 * gap) / 3)
    local group, tabs = HorizontalGroup:new{ allow_mirroring = false }, {}
    for index = 1, 3 do
        local profile = profiles:profile(index)
        local tab = Tab:new{
            name = profile.name, modified = profiles:isModified(index), selected = index == profiles.active,
            width = index == 3 and width - 2 * padding - 2 * gap - 2 * tab_width or tab_width,
            height = row_height - inset,
            callback = function() callback(index) end,
            hold_callback = function() hold_callback(index) end,
        }
        tabs[index] = tab
        group[#group + 1] = tab
        if index < 3 then group[#group + 1] = HorizontalSpan:new{ width = gap } end
    end
    return Tabs:new{
        width = width, bordersize = 0, padding = 0, padding_top = inset,
        padding_left = padding, padding_right = padding,
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        tabs = tabs, group,
    }
end

return Tabs
