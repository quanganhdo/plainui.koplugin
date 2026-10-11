-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local Provider = {}

local function hasPopup(object)
    local handler = object and object.onShowReadingStatsPopup
    if type(handler) == "function" then return true end
    -- KOReader wraps plugin event handlers in callable HandlerSandbox tables.
    local mt = type(handler) == "table" and getmetatable(handler)
    return type(mt) == "table" and type(mt.__call) == "function"
end

function Provider.findExternal(ui)
    if not ui then return end
    -- Prefer the enabled Reading Insights plugin over a standalone patch.
    if hasPopup(ui.readinginsights) then return ui.readinginsights end
    -- Other derivatives can expose the same book-progress event under their
    -- own plugin name. Only inspect modules registered on the current reader.
    for _, module in ipairs(ui) do
        if module ~= ui and hasPopup(module) then return module end
    end
    if hasPopup(ui) then return ui end
end

return Provider
