-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local userpatch = require("userpatch")

userpatch.registerPatchPluginFunc("coverbrowser", function()
    local BD = require("ui/bidi")
    local CoverBadge = require("modules.cover_badge")
    local Device = require("device")
    local Font = require("ui/font")
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local Screen = Device.screen

    local percentage_badge_cache = {}
    local percentage_face = Font:getFace("infont", 13)

    local function getReadingPercentageText(percent_finished)
        local percent = math.floor((percent_finished or 0) * 100 + 0.5)
        if percent <= 0 then
            percent = 1
        elseif percent >= 100 then
            percent = 99
        end
        return string.format("%d%%", percent)
    end

    local function getReadingPercentageBadge(percent_finished)
        local text = getReadingPercentageText(percent_finished)
        if percentage_badge_cache[text] then
            return percentage_badge_cache[text]
        end

        local border = math.max(1, Screen:scaleBySize(1))
        local padding_h = Screen:scaleBySize(3)
        local padding_top = Screen:scaleBySize(2)
        local padding_bottom = Screen:scaleBySize(3)
        local badge = CoverBadge.newTextBadge{
            text = text,
            face = percentage_face,
            padding_h = padding_h,
            padding_top = padding_top,
            padding_bottom = padding_bottom,
            border = border,
            text_y_offset = border + padding_top,
        }
        percentage_badge_cache[text] = badge
        return badge
    end

    local original_MosaicMenuItem_paintTo = MosaicMenuItem.paintTo
    function MosaicMenuItem:paintTo(bb, x, y)
        original_MosaicMenuItem_paintTo(self, bb, x, y)

        if not self.menu or self.menu.name ~= "filemanager" then
            return
        end
        if not self.been_opened then
            return
        end
        if self.status == "abandoned" then
            return
        end
        if self.status == "complete" or not self.percent_finished then
            return
        end

        local target = self[1] and self[1][1] and self[1][1][1]
        if not target or not target.dimen then
            return
        end

        local badge = getReadingPercentageBadge(self.percent_finished)
        local badge_size = badge:getSize()
        local badge_x
        if BD.mirroredUILayout() then
            badge_x = target.dimen.x + Screen:scaleBySize(5)
        else
            badge_x = target.dimen.x + target.dimen.w - badge_size.w - Screen:scaleBySize(5)
        end
        local badge_y = target.dimen.y
        CoverBadge.paint(bb, badge_x, badge_y, badge)
    end
end)
