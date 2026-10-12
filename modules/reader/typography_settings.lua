-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Event = require("ui/event")
local Screen = require("device").screen
local Profiles = require("modules.reader.typography_profiles")
local Settings = {}
local ALIGNMENT_IDS = {
    "text_align_most_left", "text_align_all_left",
    "text_align_most_justify", "text_align_all_justify",
}

function Settings.alignment(ui)
    local tweak = ui.styletweak
    if tweak and tweak.enabled then
        if tweak:isTweakEnabled(ALIGNMENT_IDS[1]) or tweak:isTweakEnabled(ALIGNMENT_IDS[2]) then return "left" end
        if tweak:isTweakEnabled(ALIGNMENT_IDS[3]) or tweak:isTweakEnabled(ALIGNMENT_IDS[4]) then return "justify" end
    end
    return "auto"
end

function Settings.capture(ui)
    local config = ui.document.configurable
    local margins = config.h_page_margins
    return {
        font = ui.font.font_face, size = config.font_size,
        weight = config.font_base_weight or 0, spacing = config.line_spacing,
        margins = { margins[1], margins[2] }, alignment = Settings.alignment(ui),
    }
end

function Settings.defaults(ui)
    local config = require("configurable"):new{}
    config:loadDefaults(require("ui/data/creoptions"))
    local tweaks = G_reader_settings:readSetting("style_tweaks") or {}
    return {
        font = G_reader_settings:readSetting("cre_font") or ui.document.default_font,
        size = config.font_size, weight = config.font_base_weight or 0,
        spacing = config.line_spacing,
        margins = { config.h_page_margins[1], config.h_page_margins[2] },
        alignment = (tweaks.text_align_most_left or tweaks.text_align_all_left) and "left"
            or (tweaks.text_align_most_justify or tweaks.text_align_all_justify) and "justify" or "auto",
    }
end

function Settings.setAlignment(ui, mode)
    if Settings.alignment(ui) == mode then return end
    local tweak = ui.styletweak
    if not tweak then return end
    tweak.enabled = true
    local desired = mode == "left" and ALIGNMENT_IDS[1] or mode == "justify" and ALIGNMENT_IDS[3]
    for _, id in ipairs(ALIGNMENT_IDS) do
        if id == desired then
            tweak.doc_tweaks[id] = not tweak.global_tweaks[id] and true or nil
        else
            tweak.doc_tweaks[id] = tweak.global_tweaks[id] and false or nil
        end
    end
    tweak:updateCssText(true)
end

function Settings.apply(ui, settings)
    local current = Settings.capture(ui)
    if Profiles.equal(current, settings) then return end
    local config = ui.document.configurable
    if current.font ~= settings.font then ui.font:onSetFont(settings.font) end
    if current.size ~= settings.size then
        ui.font.configurable.font_size = settings.size
        ui.document:setFontSize(Screen:scaleBySize(settings.size))
        ui:handleEvent(Event:new("UpdatePos"))
    end
    if current.weight ~= settings.weight then ui.font:onSetFontBaseWeight(settings.weight) end
    if current.spacing ~= settings.spacing then
        ui.font.configurable.line_spacing = settings.spacing
        ui.document:setInterlineSpacePercent(settings.spacing)
        ui:handleEvent(Event:new("UpdatePos"))
    end
    if current.margins[1] ~= settings.margins[1] or current.margins[2] ~= settings.margins[2] then
        local margins = { settings.margins[1], settings.margins[2] }
        config.h_page_margins, ui.typeset.configurable.h_page_margins = margins, margins
        ui.typeset:onSetPageHorizMargins(margins)
    end
    Settings.setAlignment(ui, settings.alignment)
end

function Settings.saveDefaults(ui, settings)
    -- Keep KOReader's defaults consistent with the first profile. Existing book
    -- snapshots are never rewritten here; each book resolves its choice on open.
    G_reader_settings:saveSetting("cre_font", settings.font)
    G_reader_settings:saveSetting("copt_font_size", settings.size)
    G_reader_settings:saveSetting("copt_font_base_weight", settings.weight)
    G_reader_settings:saveSetting("copt_line_spacing", settings.spacing)
    G_reader_settings:saveSetting("copt_h_page_margins", { settings.margins[1], settings.margins[2] })
    -- Do not change global CSS tweaks: they also affect customized books with
    -- no document override. Profile alignment is applied per book on opening.
end

return Settings
