-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local userpatch = require("userpatch")

userpatch.registerPatchPluginFunc("coverbrowser", function(CoverBrowser)
    local BD = require("ui/bidi")
    local Blitbuffer = require("ffi/blitbuffer")
    local Device = require("device")
    local Font = require("ui/font")
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local FileChooser = require("ui/widget/filechooser")
    local Size = require("ui/size")
    local TextWidget = require("ui/widget/textwidget")
    local Screen = Device.screen

    local complete_badge
    local complete_face = Font:getFace("infont", 13)
    local OVERLAY_LIGHTEN_FACTOR = 0.60
    local OVERLAY_LIGHTEN_COLOR = Blitbuffer.Color8A(0xFF, math.floor(0xFF * OVERLAY_LIGHTEN_FACTOR + 0.5))

    local function lightenRoundedRect(bb, x, y, w, h, radius)
        radius = math.floor(math.min(radius or 0, w / 2, h / 2))
        if radius <= 0 then
            bb:lightenRect(x, y, w, h, OVERLAY_LIGHTEN_FACTOR)
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
                    bb:setPixelBlend(x + dx, y + dy, OVERLAY_LIGHTEN_COLOR)
                end
            end
        end
    end

    local function paintTranslucentBadge(bb, x, y, badge)
        lightenRoundedRect(bb, x, y, badge.width, badge.height, badge.radius)
        bb:paintBorder(
            x, y, badge.width, badge.height, badge.border,
            Blitbuffer.COLOR_BLACK, badge.radius,
            G_reader_settings:nilOrTrue("anti_alias_ui")
        )
        local text_x = x + math.floor((badge.width - badge.text_size.w) / 2)
        local text_y = y + math.floor((badge.height - badge.text_size.h) / 2)
        badge.text_widget:paintTo(bb, text_x, text_y)
    end

    local function getCompleteBadge()
        if complete_badge then
            return complete_badge
        end

        local text_widget = TextWidget:new{
            text = "\u{2713}",
            face = complete_face,
            fgcolor = Blitbuffer.COLOR_BLACK,
        }
        local text_size = text_widget:getSize()
        local padding = Screen:scaleBySize(3)
        local inner_side = math.max(text_size.w, text_size.h)
        local border = math.max(1, Size.line.thin)
        local badge_side = inner_side + 2 * padding + 2 * border
        complete_badge = {
            text_widget = text_widget,
            text_size = text_size,
            width = badge_side,
            height = badge_side,
            border = border,
            radius = math.floor(badge_side / 2),
        }
        function complete_badge:getSize()
            return { w = self.width, h = self.height }
        end
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
        paintTranslucentBadge(bb, badge_x, badge_y, badge)
    end
end)
