-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local userpatch = require("userpatch")

userpatch.registerPatchPluginFunc("coverbrowser", function(CoverBrowser)
    local BD = require("ui/bidi")
    local CoverBadge = require("modules.cover_badge")
    local Device = require("device")
    local Font = require("ui/font")
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local FileChooser = require("ui/widget/filechooser")
    local Size = require("ui/size")
    local Screen = Device.screen

    local complete_badge
    local complete_face = Font:getFace("infont", 13)

    local function getCompleteBadge()
        if complete_badge then
            return complete_badge
        end

        local padding = Screen:scaleBySize(3)
        local border = math.max(1, Size.line.thin)
        local measured_badge = CoverBadge.newTextBadge{
            text = "\u{2713}",
            face = complete_face,
        }
        local inner_side = math.max(measured_badge.text_size.w, measured_badge.text_size.h)
        local badge_side = inner_side + 2 * padding + 2 * border
        measured_badge.text_widget:free()
        complete_badge = CoverBadge.newTextBadge{
            text = "\u{2713}",
            face = complete_face,
            padding = padding,
            border = border,
            width = badge_side,
            height = badge_side,
            radius = math.floor(badge_side / 2),
        }
        return complete_badge
    end

    local original_setupFileManagerDisplayMode = CoverBrowser.setupFileManagerDisplayMode
    function CoverBrowser.setupFileManagerDisplayMode(...)
        original_setupFileManagerDisplayMode(...)
        FileChooser._do_hint_opened = false
    end

    FileChooser._do_hint_opened = false

    local original_MosaicMenuItem_paintTo = MosaicMenuItem.paintTo
    function MosaicMenuItem:paintTo(bb, x, y)
        original_MosaicMenuItem_paintTo(self, bb, x, y)

        if not self.menu or self.menu.name ~= "filemanager" then
            return
        end
        if not self.been_opened or self.status ~= "complete" then
            return
        end

        local target = self[1] and self[1][1] and self[1][1][1]
        if not target or not target.dimen then
            return
        end

        local badge = getCompleteBadge()
        local badge_size = badge:getSize()
        local badge_x
        if BD.mirroredUILayout() then
            badge_x = target.dimen.x + Screen:scaleBySize(5)
        else
            badge_x = target.dimen.x + target.dimen.w - badge_size.w - Screen:scaleBySize(5)
        end
        local badge_y = target.dimen.y + target.dimen.h - badge_size.h - Screen:scaleBySize(5)
        CoverBadge.paint(bb, badge_x, badge_y, badge)
    end
end)
