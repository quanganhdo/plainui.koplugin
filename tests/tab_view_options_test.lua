package.path = "./?.lua;./?/init.lua;" .. package.path

local TestHelper = require("tests.test_helper")
local TabViewOptions = require("modules.tab_view_options")

local assertEqual = TestHelper.assertEqual
local test, run = TestHelper.newSuite()

local saved_settings = G_reader_settings

local function withSettings(settings, fn)
    local saved
    G_reader_settings = {
        readSetting = function(_self, key)
            if key == TabViewOptions.SETTINGS_KEY then
                return settings
            end
        end,
        saveSetting = function(_self, key, value)
            if key == TabViewOptions.SETTINGS_KEY then
                saved = value
                settings = value
            end
        end,
    }
    local ok, err = pcall(function()
        fn(function()
            return saved
        end)
    end)
    G_reader_settings = saved_settings
    if not ok then
        error(err)
    end
end

test("defaults preserve current behavior", function()
    withSettings(nil, function()
        local options = TabViewOptions.getAll()

        assertEqual(options.books.filter, "legacy")
        assertEqual(options.books.sort, "legacy")
        assertEqual(options.authors.filter, "all")
        assertEqual(options.authors.folder_sort, "name")
        assertEqual(options.series.filter, "all")
        assertEqual(options.series.folder_sort, "name")
        assertEqual(options.tags.filter, "all")
        assertEqual(options.tags.folder_sort, "name")
    end)
end)

test("books accepts legacy values and metadata tabs do not", function()
    withSettings({
        books = {
            filter = "legacy",
            sort = "legacy",
        },
        authors = {
            filter = "legacy",
            folder_sort = "legacy",
        },
    }, function()
        local books = TabViewOptions.get("books")
        local authors = TabViewOptions.get("authors")

        assertEqual(books.filter, "legacy")
        assertEqual(books.sort, "legacy")
        assertEqual(authors.filter, "all")
        assertEqual(authors.folder_sort, "name")
    end)
end)

test("valid explicit metadata options are returned", function()
    withSettings({
        series = {
            filter = "finished",
            folder_sort = "book_count",
        },
    }, function()
        local series = TabViewOptions.get("series")

        assertEqual(series.filter, "finished")
        assertEqual(series.folder_sort, "book_count")
    end)
end)

test("keywords normalizes to tags", function()
    withSettings({
        tags = {
            filter = "reading",
            folder_sort = "book_count",
        },
    }, function()
        local tags = TabViewOptions.get("keywords")

        assertEqual(tags.filter, "reading")
        assertEqual(tags.folder_sort, "book_count")
    end)
end)

test("set persists valid options", function()
    withSettings(nil, function(getSaved)
        local ok = TabViewOptions.set("tags", "folder_sort", "book_count")
        local saved = getSaved()

        assertEqual(ok, true)
        assertEqual(saved.tags.folder_sort, "book_count")
        assertEqual(saved.tags.filter, "all")
        assertEqual(saved.books.filter, "legacy")
    end)
end)

test("set rejects metadata legacy values", function()
    withSettings(nil, function(getSaved)
        local ok = TabViewOptions.set("authors", "filter", "legacy")

        assertEqual(ok, false)
        assertEqual(getSaved(), nil)
    end)
end)

run()
