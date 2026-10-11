-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local UIManager = require("ui/uimanager")

local NavigationHistory = {}
NavigationHistory.__index = NavigationHistory

function NavigationHistory.new(ui)
    return setmetatable({ ui = ui, hooks = {}, active = false }, NavigationHistory)
end

-- ReaderLink skips exactly one top entry when it equals the current location.
-- In particular, its forward stack normally has the current location on top.
function NavigationHistory:getDestination(stack)
    local index = #stack
    if index > 0 and self.ui.link:compareLocationToCurrent(stack[index]) then
        index = index - 1
    end
    return stack[index]
end

function NavigationHistory:getDestinations()
    local link = self.ui.link
    return self:getDestination(link.location_stack or {}),
        self:getDestination(link.forward_location_stack or {})
end

function NavigationHistory:getPageLabel(location)
    if not location then return nil end
    local page
    if location.xpointer then
        local pagemap = self.ui.pagemap
        if pagemap and pagemap:wantsPageLabels() then
            local label = pagemap:getXPointerPageLabel(location.xpointer)
            if label and label ~= "" then
                return pagemap:cleanPageLabel(label)
            end
        end
        page = self.ui.document:getPageFromXPointer(location.xpointer)
    elseif location[1] then
        page = location[1].page
    end
    if page and page > 0 then return tostring(page) end
end

function NavigationHistory:queueRefresh(activate)
    if self.stopped then return end
    if activate then self.active = true end
    if self.pending_refresh then return end
    self.pending_refresh = function()
        self.pending_refresh = nil
        if not self.stopped then self:refresh() end
    end
    -- History is pushed before navigation; wait for the final location and for
    -- the TOC/search/dialog that initiated the jump to finish closing.
    UIManager:nextTick(self.pending_refresh)
end

function NavigationHistory:hook(target, name, callback)
    local original = target[name]
    if type(original) ~= "function" then return end
    local own_original = rawget(target, name)
    local installed = function(object, ...)
        local result = original(object, ...)
        if not self.stopped then callback(object, ...) end
        return result
    end
    target[name] = installed
    table.insert(self.hooks, { target = target, name = name,
        original = own_original, installed = installed })
end

function NavigationHistory:install()
    if self.installed or not self.ui.link then return end
    self.installed = true
    local link = self.ui.link
    for _, name in ipairs({ "addCurrentLocationToStack", "onGoBackLink", "onGoForwardLink" }) do
        self:hook(link, name, function() self:queueRefresh(true) end)
    end
    for _, name in ipairs({ "onClearLocationStack", "onClearForwardLocationStack", "popFromLocationStack" }) do
        self:hook(link, name, function() self:queueRefresh() end)
    end
    self:hook(UIManager, "show", function(_, widget)
        if not self.changing_footer and not (widget and widget.toast) then
            self:hide()
            self:queueRefresh()
        end
    end)
    self:hook(UIManager, "close", function()
        if not self.changing_footer then self:queueRefresh() end
    end)
end

function NavigationHistory:isReaderUncovered()
    local reader_found = false
    for _, window in ipairs(UIManager._window_stack) do
        local widget = window.widget
        if widget == (self.ui.dialog or self.ui) then
            reader_found = true
        elseif reader_found and widget ~= self.footer and not widget.toast then
            return false
        end
    end
    return reader_found
end

function NavigationHistory:hide()
    if not self.footer then return end
    local footer = self.footer
    self.footer = nil
    self.changing_footer = true
    UIManager:close(footer, "ui", footer.dimen)
    self.changing_footer = false
end

function NavigationHistory:refresh()
    local back, forward = self:getDestinations()
    if not self.active or not (back or forward) or not self:isReaderUncovered() then
        self:hide()
        return
    end
    if self.footer then
        UIManager:setDirty(self.footer, "ui", self.footer.dimen)
        return
    end
    local Footer = require("modules.reader.return_footer")
    self.footer = Footer:new{ history = self }
    local reader = self.ui.dialog or self.ui
    -- UIManager otherwise sends input only to the top window. Keep normal
    -- reader gestures and controls reachable whenever the footer declines it.
    self.footer.active_widgets = { reader }
    self.footer.disable_double_tap = reader.disable_double_tap
    self.footer.allow_concurrent_taps = reader.allow_concurrent_taps
    self.footer.tap_interval_override = reader.tap_interval_override
    self.changing_footer = true
    UIManager:show(self.footer, "ui", self.footer.dimen, 0, self.footer.dimen.y)
    self.changing_footer = false
end

function NavigationHistory:goBack()
    self.ui.link:onGoBackLink()
end

function NavigationHistory:goForward()
    self.ui.link:onGoForwardLink()
end

function NavigationHistory:stayHere()
    -- Dismiss the UI, preserving KOReader's history for gestures/menus and the
    -- next jump. Normal page turns must not reactivate a dismissed footer.
    self.active = false
    self:hide()
end

function NavigationHistory:onSetDimensions()
    self:hide()
    self:queueRefresh()
end

function NavigationHistory:stop()
    self.stopped = true
    if self.pending_refresh then
        UIManager:unschedule(self.pending_refresh)
        self.pending_refresh = nil
    end
    self:hide()
    for i = #self.hooks, 1, -1 do
        local hook = self.hooks[i]
        if hook.target[hook.name] == hook.installed then
            hook.target[hook.name] = hook.original
        end
    end
    self.hooks = {}
end

return NavigationHistory
