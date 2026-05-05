package.path = "./?.lua;./?/init.lua;" .. package.path

local FilterState = require("modules.filter_state")
local TestHelper = require("tests.test_helper")
local VirtualPath = require("modules.virtual_path")

local assertEqual = TestHelper.assertEqual
local assertTruthy = TestHelper.assertTruthy
local test, run = TestHelper.newSuite()

local function virtualPath(...)
    return table.concat({ "/books", VirtualPath.ROOT_SYMBOL, ... }, "/")
end

test("parse returns filter state in path order with deepest leaf last", function()
    local base_dir, active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        VirtualPath.SERIES_SYMBOL, "Foo"
    ))

    assertEqual(base_dir, "/books")
    assertEqual(active_dimension, nil)
    assertEqual(#state.trail, 2)
    assertEqual(state.trail[1].dimension, "authors")
    assertEqual(state.trail[1].value, "Alice")
    assertEqual(state.trail[2].dimension, "series")
    assertEqual(state.trail[2].value, "Foo")
    assertEqual(VirtualPath.getLeafEntry(state).dimension, "series")
    assertEqual(VirtualPath.getLeafEntry(state).value, "Foo")
end)

test("parse decodes special characters before storing and displaying values", function()
    local value = "A/B % C [x] * ? #"
    local encoded = VirtualPath.encodeValue(value)
    local _base_dir, _active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, encoded
    ))

    assertEqual(encoded, "A%2FB%20%25%20C%20%5Bx%5D%20%2A%20%3F%20%23")
    assertEqual(state.trail[1].value, value)
    assertEqual(VirtualPath.displayValue(state.trail[1].value), value)
    assertTruthy(state.selected.authors[value])
end)

test("parse preserves empty and nil-like facet display values", function()
    local _base_dir, _active_dimension, empty_state = VirtualPath.parse(virtualPath(
        VirtualPath.KEYWORD_SYMBOL, VirtualPath.encodeValue("")
    ))
    local _base_dir2, _active_dimension2, missing_state = VirtualPath.parse(virtualPath(
        VirtualPath.KEYWORD_SYMBOL, VirtualPath.encodeValue(false)
    ))

    assertEqual(empty_state.trail[1].value, "")
    assertEqual(VirtualPath.displayValue(empty_state.trail[1].value), "")
    assertEqual(missing_state.trail[1].value, false)
    assertEqual(VirtualPath.displayValue(missing_state.trail[1].value), VirtualPath.EMPTY_VALUE_SYMBOL)
end)

test("parse ignores unknown fragments without a pending dimension", function()
    local _base_dir, active_dimension, state = VirtualPath.parse(virtualPath(
        "unknown",
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        "ignored"
    ))

    assertEqual(active_dimension, nil)
    assertEqual(#state.trail, 1)
    assertEqual(state.trail[1].dimension, "authors")
    assertEqual(state.trail[1].value, "Alice")
end)

test("parse preserves dangling dimensions as active dimensions", function()
    local _base_dir, active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        VirtualPath.KEYWORD_SYMBOL
    ))

    assertEqual(active_dimension, "keywords")
    assertEqual(state.active_dimension, "keywords")
    assertEqual(#state.trail, 1)
    assertEqual(state.trail[1].dimension, "authors")
end)

test("parse tolerates trailing slashes", function()
    local base_dir, active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, "Alice"
    ) .. "/")

    assertEqual(base_dir, "/books")
    assertEqual(active_dimension, nil)
    assertEqual(#state.trail, 1)
    assertEqual(state.trail[1].value, "Alice")
end)

test("findRoot requires the virtual root symbol to be a path segment", function()
    local path = "/books/" .. VirtualPath.ROOT_SYMBOL .. "-notes"
    local base_dir, active_dimension, state = VirtualPath.parse(path)

    assertEqual(VirtualPath.findRoot(path), nil)
    assertEqual(base_dir, nil)
    assertEqual(active_dimension, nil)
    assertEqual(state, nil)
end)

test("active dimension is separate from deepest selected leaf", function()
    local _base_dir, active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        VirtualPath.SERIES_SYMBOL, "Foo",
        VirtualPath.KEYWORD_SYMBOL
    ))

    assertEqual(active_dimension, "keywords")
    assertEqual(state.active_dimension, "keywords")
    assertEqual(#state.trail, 2)
    assertEqual(VirtualPath.getLeafEntry(state).dimension, "series")
    assertEqual(VirtualPath.getLeafEntry(state).value, "Foo")
end)

test("multi-value repeated dimensions accumulate distinct values", function()
    local _base_dir, _active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        VirtualPath.AUTHOR_SYMBOL, "Bob",
        VirtualPath.KEYWORD_SYMBOL, "sci-fi",
        VirtualPath.KEYWORD_SYMBOL, "award"
    ))

    assertEqual(#state.trail, 4)
    assertEqual(#state.filters.authors, 2)
    assertEqual(#state.filters.keywords, 2)
    assertTruthy(state.selected.authors.Alice)
    assertTruthy(state.selected.authors.Bob)
    assertTruthy(state.selected.keywords["sci-fi"])
    assertTruthy(state.selected.keywords.award)
end)

test("duplicate repeated values are ignored", function()
    local _base_dir, _active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        VirtualPath.AUTHOR_SYMBOL, "Alice"
    ))

    assertEqual(#state.trail, 1)
    assertEqual(#state.filters.authors, 1)
    assertTruthy(state.selected.authors.Alice)
end)

test("single-use repeated dimensions keep their first value", function()
    local _base_dir, _active_dimension, state = VirtualPath.parse(virtualPath(
        VirtualPath.SERIES_SYMBOL, "Foo",
        VirtualPath.AUTHOR_SYMBOL, "Alice",
        VirtualPath.SERIES_SYMBOL, "Bar"
    ))

    assertEqual(#state.trail, 2)
    assertEqual(state.trail[1].dimension, "series")
    assertEqual(state.trail[1].value, "Foo")
    assertEqual(state.trail[2].dimension, "authors")
    assertEqual(state.trail[2].value, "Alice")
    assertEqual(#state.filters.series, 1)
    assertEqual(state.filters.series[1], "Foo")
    assertTruthy(state.selected.series.Foo)
    assertEqual(state.selected.series.Bar, nil)
end)

test("withoutDimension removes a dimension while preserving remaining trail order", function()
    local state = FilterState.new("/books")
    FilterState.addFilter(state, "authors", "Alice")
    FilterState.addFilter(state, "series", "Foo")
    FilterState.addFilter(state, "keywords", "award")

    local without_series = FilterState.withoutDimension(state, "series")

    assertEqual(#without_series.trail, 2)
    assertEqual(without_series.trail[1].dimension, "authors")
    assertEqual(without_series.trail[1].value, "Alice")
    assertEqual(without_series.trail[2].dimension, "keywords")
    assertEqual(without_series.trail[2].value, "award")
    assertEqual(without_series.selected.series, nil)
end)

run()
