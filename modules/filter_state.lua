-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local FilterState = {}

FilterState.DIMENSIONS = {
    authors = {
        column = "authors",
        multi_value = true,
        repeat_mode = "and",
    },
    series = {
        column = "series",
        multi_value = false,
        repeat_mode = "once",
    },
    keywords = {
        column = "keywords",
        multi_value = true,
        repeat_mode = "and",
    },
}

FilterState.ORDERED_DIMENSIONS = {
    "authors",
    "series",
    "keywords",
}

local function ensureDimension(filters, dimension)
    if not filters[dimension] then
        filters[dimension] = {}
    end
    return filters[dimension]
end

function FilterState.isDimension(dimension)
    return FilterState.DIMENSIONS[dimension] ~= nil
end

function FilterState.new(base_dir, active_dimension)
    return {
        base_dir = base_dir,
        active_dimension = active_dimension,
        filters = {},
        trail = {},
        selected = {},
    }
end

function FilterState.clone(state)
    local clone = FilterState.new(state and state.base_dir, state and state.active_dimension)
    if not state then
        return clone
    end

    for dimension, values in pairs(state.filters or {}) do
        clone.filters[dimension] = {}
        for i, value in ipairs(values) do
            clone.filters[dimension][i] = value
        end
    end
    for i, entry in ipairs(state.trail or {}) do
        clone.trail[i] = {
            dimension = entry.dimension,
            value = entry.value,
        }
    end
    for dimension, values in pairs(state.selected or {}) do
        clone.selected[dimension] = {}
        for value, selected in pairs(values) do
            clone.selected[dimension][value] = selected
        end
    end
    return clone
end

function FilterState.addFilter(state, dimension, value)
    if not state or not FilterState.isDimension(dimension) then
        return state
    end

    local definition = FilterState.DIMENSIONS[dimension]
    if definition.repeat_mode == "replace" then
        state.filters[dimension] = {}
        state.selected[dimension] = {}
        local next_trail = {}
        for _, entry in ipairs(state.trail) do
            if entry.dimension ~= dimension then
                table.insert(next_trail, entry)
            end
        end
        state.trail = next_trail
    elseif definition.repeat_mode == "once" and state.filters[dimension] and #state.filters[dimension] > 0 then
        return state
    end

    local selected = state.selected[dimension]
    if not selected then
        selected = {}
        state.selected[dimension] = selected
    end
    if selected[value] then
        return state
    end

    table.insert(ensureDimension(state.filters, dimension), value)
    selected[value] = true
    table.insert(state.trail, {
        dimension = dimension,
        value = value,
    })
    return state
end

function FilterState.withoutDimension(state, dimension)
    local clone = FilterState.new(state and state.base_dir, state and state.active_dimension)
    if not state then
        return clone
    end

    for _, entry in ipairs(state.trail or {}) do
        if entry.dimension ~= dimension then
            FilterState.addFilter(clone, entry.dimension, entry.value)
        end
    end
    return clone
end

return FilterState
