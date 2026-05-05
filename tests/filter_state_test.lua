package.path = "./?.lua;./?/init.lua;" .. package.path

local FilterState = require("modules.filter_state")
local TestHelper = require("tests.test_helper")

local assertEqual = TestHelper.assertEqual
local assertTruthy = TestHelper.assertTruthy
local test, run = TestHelper.newSuite()

test("addFilter ignores unknown dimensions", function()
    local state = FilterState.new("/books")

    FilterState.addFilter(state, "publisher", "Acme")

    assertEqual(#state.trail, 0)
    assertEqual(next(state.filters), nil)
    assertEqual(next(state.selected), nil)
end)

test("addFilter accumulates multi-value dimensions and skips duplicates", function()
    local state = FilterState.new("/books")

    FilterState.addFilter(state, "authors", "Alice")
    FilterState.addFilter(state, "authors", "Bob")
    FilterState.addFilter(state, "authors", "Alice")

    assertEqual(#state.trail, 2)
    assertEqual(#state.filters.authors, 2)
    assertEqual(state.filters.authors[1], "Alice")
    assertEqual(state.filters.authors[2], "Bob")
    assertTruthy(state.selected.authors.Alice)
    assertTruthy(state.selected.authors.Bob)
end)

test("addFilter keeps single-use dimensions at their first value", function()
    local state = FilterState.new("/books")

    FilterState.addFilter(state, "series", "Foo")
    FilterState.addFilter(state, "authors", "Alice")
    FilterState.addFilter(state, "keywords", "award")
    FilterState.addFilter(state, "series", "Bar")

    assertEqual(#state.trail, 3)
    assertEqual(state.trail[1].dimension, "series")
    assertEqual(state.trail[1].value, "Foo")
    assertEqual(state.trail[2].dimension, "authors")
    assertEqual(state.trail[2].value, "Alice")
    assertEqual(state.trail[3].dimension, "keywords")
    assertEqual(state.trail[3].value, "award")
    assertEqual(#state.filters.series, 1)
    assertEqual(state.filters.series[1], "Foo")
    assertTruthy(state.selected.series.Foo)
    assertEqual(state.selected.series.Bar, nil)
end)

test("clone deep-copies filters trail and selected values", function()
    local state = FilterState.new("/books", "keywords")
    FilterState.addFilter(state, "authors", "Alice")
    FilterState.addFilter(state, "series", "Foo")

    local clone = FilterState.clone(state)
    FilterState.addFilter(clone, "authors", "Bob")
    clone.trail[1].value = "Changed"
    clone.selected.authors.Alice = nil

    assertEqual(clone.base_dir, "/books")
    assertEqual(clone.active_dimension, "keywords")
    assertEqual(#clone.filters.authors, 2)
    assertEqual(#state.filters.authors, 1)
    assertEqual(state.trail[1].value, "Alice")
    assertTruthy(state.selected.authors.Alice)
end)

test("withoutDimension handles nil input as an empty state", function()
    local state = FilterState.withoutDimension(nil, "authors")

    assertEqual(state.base_dir, nil)
    assertEqual(state.active_dimension, nil)
    assertEqual(#state.trail, 0)
    assertEqual(next(state.filters), nil)
    assertEqual(next(state.selected), nil)
end)

run()
