package.path = "./?.lua;./?/init.lua;" .. package.path

local TestHelper = require("tests.test_helper")
local VirtualLeaf = require("modules.virtual_leaf")

local assertEqual = TestHelper.assertEqual
local test, run = TestHelper.newSuite()

test("markMetadataLeaf records leaf metadata without resolving a representative file", function()
    local item = {
        path = "/books/meta/Alice",
    }

    VirtualLeaf.markMetadataLeaf(item, 12, "Alice")

    assertEqual(item.is_virtual_metadata_leaf, true)
    assertEqual(item.virtual_leaf_count, 12)
    assertEqual(item.virtual_leaf_title, "Alice")
    assertEqual(item.representative_filepath, nil)
    assertEqual(item.representative_filepath_checked, nil)
end)

test("ensureRepresentativeFilepath resolves representative once for render items", function()
    local calls = 0
    local cover_browser = {
        getRepresentativeFilepath = function(_self, path)
            calls = calls + 1
            assertEqual(path, "/books/meta/Alice")
            return "/books/a.epub"
        end,
    }
    local item = {
        entry = VirtualLeaf.markMetadataLeaf({
            path = "/books/meta/Alice",
        }, 12, "Alice"),
    }

    local first = VirtualLeaf.ensureRepresentativeFilepath(item, cover_browser)
    local second = VirtualLeaf.ensureRepresentativeFilepath(item, cover_browser)

    assertEqual(first, "/books/a.epub")
    assertEqual(second, "/books/a.epub")
    assertEqual(item.entry.representative_filepath, "/books/a.epub")
    assertEqual(calls, 1)
end)

test("ensureRepresentativeFilepath remembers missing representatives", function()
    local calls = 0
    local cover_browser = {
        getRepresentativeFilepath = function()
            calls = calls + 1
            return nil
        end,
    }
    local item = {
        entry = VirtualLeaf.markMetadataLeaf({
            path = "/books/meta/Empty",
        }, 0, "Empty"),
    }

    VirtualLeaf.ensureRepresentativeFilepath(item, cover_browser)
    VirtualLeaf.ensureRepresentativeFilepath(item, cover_browser)

    assertEqual(item.entry.representative_filepath, nil)
    assertEqual(item.entry.representative_filepath_checked, true)
    assertEqual(calls, 1)
end)

run()
