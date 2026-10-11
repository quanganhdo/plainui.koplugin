-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

-- The preset store and the book's choice are independent. A customized book
-- owns a complete snapshot; a follower resolves its preset again on opening.
local Profiles = {}
Profiles.__index = Profiles
Profiles.GLOBAL_KEY = "plainui_typography_profiles"
Profiles.BOOK_KEY = "plainui_typography_profile"
local IDS = { "default", "profile_2", "profile_3" }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function Profiles.equal(a, b)
    if not a or not b then return false end
    for _, key in ipairs{ "font", "size", "weight", "spacing", "alignment" } do
        if a[key] ~= b[key] then return false end
    end
    return a.margins[1] == b.margins[1] and a.margins[2] == b.margins[2]
end

function Profiles.valid(settings)
    return type(settings) == "table" and type(settings.font) == "string"
        and type(settings.size) == "number" and type(settings.weight) == "number"
        and type(settings.spacing) == "number" and type(settings.margins) == "table"
        and type(settings.margins[1]) == "number" and type(settings.margins[2]) == "number"
        and (settings.alignment == "auto" or settings.alignment == "left" or settings.alignment == "justify")
end

function Profiles.new(global_settings, book_settings, defaults, current)
    local self = setmetatable({ global_settings = global_settings, book_settings = book_settings }, Profiles)
    local store = global_settings:readSetting(self.GLOBAL_KEY)
    if type(store) ~= "table" or store.version ~= 1 or type(store.profiles) ~= "table" then
        store = { version = 1, profiles = {
            { id = IDS[1], name = "Everyday", settings = copy(defaults) },
            { id = IDS[2], name = "Custom 1" },
            { id = IDS[3], name = "Custom 2" },
        } }
    end
    self.store = copy(store)
    for index, id in ipairs(IDS) do
        local profile = self.store.profiles[index]
        if type(profile) ~= "table" then profile = {}; self.store.profiles[index] = profile end
        profile.id = id
        if type(profile.name) ~= "string" or profile.name == "" then
            profile.name = index == 1 and "Everyday" or "Custom " .. (index - 1)
        end
        if not self.valid(profile.settings) then profile.settings = index == 1 and copy(defaults) or nil end
    end
    global_settings:saveSetting(self.GLOBAL_KEY, copy(self.store))
    local book = book_settings:readSetting(self.BOOK_KEY)
    if type(book) ~= "table" or book.version ~= 1 or type(book.variants) ~= "table" then
        book = { version = 1, active = IDS[1], variants = {} }
    end
    self.book = copy(book)
    self.active = 1
    for index, id in ipairs(IDS) do if book.active == id then self.active = index end end
    self.book.active = IDS[self.active]
    local variant = self.book.variants[self.book.active]
    if type(variant) ~= "table" or not self.valid(variant.last_applied) then
        variant = { last_applied = copy(current) }
        if not self.equal(current, self:profile().settings) and not self.equal(current, defaults) then
            variant.custom = copy(current)
        end
        self.book.variants[self.book.active] = variant
    elseif not self.equal(current, variant.last_applied) then
        -- Native KOReader controls may have changed settings since our last save.
        variant.custom = not self.equal(current, self:profile().settings) and copy(current) or nil
        variant.last_applied = copy(current)
    end
    if not self.valid(variant.custom) then variant.custom = nil end
    self.current = copy(variant.custom or self:profile().settings or current)
    variant.last_applied = copy(self.current)
    self:persistBook()
    return self
end

function Profiles:profile(index)
    return self.store.profiles[index or self.active]
end

function Profiles:persistBook()
    self.book_settings:saveSetting(self.BOOK_KEY, copy(self.book))
end

function Profiles:record(current)
    local variant = self.book.variants[self.book.active]
    if not self.equal(current, variant.last_applied) then
        variant.custom = not self.equal(current, self:profile().settings) and copy(current) or nil
    end
    variant.last_applied, self.current = copy(current), copy(current)
    self:persistBook()
end

function Profiles:isModified(index)
    index = index or self.active
    local variant = self.book.variants[IDS[index]]
    return variant ~= nil and variant.custom ~= nil
        and not self.equal(variant.custom, self:profile(index).settings)
end

function Profiles:select(index, current)
    assert(self.store.profiles[index], "Unknown typography profile")
    self:record(current)
    self.active, self.book.active = index, IDS[index]
    local variant = self.book.variants[self.book.active]
    if not variant then
        variant = {}
        if not self:profile().settings then variant.custom = copy(current) end
        self.book.variants[self.book.active] = variant
    end
    self.current = copy(variant.custom or self:profile().settings or current)
    variant.last_applied = copy(self.current)
    self:persistBook()
    return copy(self.current)
end

function Profiles:reset()
    local settings = self:profile().settings
    if not settings then return nil end
    self.book.variants[self.book.active] = { last_applied = copy(settings) }
    self.current = copy(settings)
    self:persistBook()
    return copy(settings)
end

function Profiles:rename(name, index)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false end
    self:profile(index).name = name
    self.global_settings:saveSetting(self.GLOBAL_KEY, copy(self.store))
    if self.global_settings.flush then self.global_settings:flush() end
    return true
end

function Profiles:save(name, current)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false end
    self:profile().settings = copy(current)
    self:profile().name = name
    self.current = copy(current)
    self.book.variants[self.book.active] = { last_applied = copy(current) }
    self.global_settings:saveSetting(self.GLOBAL_KEY, copy(self.store))
    if self.global_settings.flush then self.global_settings:flush() end
    self:persistBook()
    return true
end

return Profiles
