package.path = "./?.lua;./?/init.lua;" .. package.path

local saved_ffi_util = package.loaded["ffi/util"]
package.loaded["ffi/util"] = {
    strcoll = function(a, b)
        return a < b
    end,
}

local MetadataSort = require("modules.metadata_sort")
local TestHelper = require("tests.test_helper")

package.loaded["ffi/util"] = saved_ffi_util

local assertEqual = TestHelper.assertEqual
local test, run = TestHelper.newSuite()

test("sortFacetValues sorts by name by default with missing values last", function()
    local values = {
        { "Zed", 1 },
        { false, 99 },
        { "Alpha", 3 },
        { "Alpha", 1 },
    }

    MetadataSort.sortFacetValues(values, "name")

    assertEqual(values[1][1], "Alpha")
    assertEqual(values[1][2], 1)
    assertEqual(values[2][1], "Alpha")
    assertEqual(values[2][2], 3)
    assertEqual(values[3][1], "Zed")
    assertEqual(values[4][1], false)
end)

test("sortFacetValues sorts by book count descending with name tie-breaker", function()
    local values = {
        { "Zed", 2 },
        { "Alpha", 3 },
        { "Beta", 3 },
        { false, 10 },
    }

    MetadataSort.sortFacetValues(values, "book_count")

    assertEqual(values[1][1], "Alpha")
    assertEqual(values[2][1], "Beta")
    assertEqual(values[3][1], "Zed")
    assertEqual(values[4][1], false)
end)

run()
