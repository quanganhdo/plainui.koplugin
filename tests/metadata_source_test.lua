package.path = "./?.lua;./?/init.lua;" .. package.path

local file_check_counts = {
    attributes = {},
    providers = {},
}
local book_status_by_path = {}

package.preload["ffi/util"] = function()
    return {
        template = function(format, ...)
            local args = { ... }
            return (format:gsub("%%(%d+)", function(index)
                return tostring(args[tonumber(index)])
            end))
        end,
    }
end

package.preload["document/documentregistry"] = function()
    return {
        hasProvider = function(_self, path)
            file_check_counts.providers[path] = (file_check_counts.providers[path] or 0) + 1
            return not path:find("no_provider", 1, true)
        end,
    }
end

package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, attr)
            file_check_counts.attributes[path] = (file_check_counts.attributes[path] or 0) + 1
            if attr == "mode" and not path:find("missing", 1, true) then
                return "file"
            end
        end,
    }
end

package.preload["util"] = function()
    return {
        gsplit = function(text, separator)
            local parts = {}
            local pattern = string.format("([^%s]+)", separator)
            for part in tostring(text):gmatch(pattern) do
                parts[#parts + 1] = part
            end
            local index = 0
            return function()
                index = index + 1
                return parts[index]
            end
        end,
    }
end

package.preload["ui/widget/booklist"] = function()
    return {
        getBookStatus = function(path)
            return book_status_by_path[path] or "new"
        end,
    }
end

local FilterState = require("modules.filter_state")
local MetadataSource = require("modules.metadata_source")
local TestHelper = require("tests.test_helper")

local assertContains = TestHelper.assertContains
local assertEqual = TestHelper.assertEqual
local assertTruthy = TestHelper.assertTruthy
local test, run = TestHelper.newSuite()

local function resetFileCheckCounts()
    file_check_counts.attributes = {}
    file_check_counts.providers = {}
end

local function makeManager(rows)
    MetadataSource.clearCache()
    resetFileCheckCounts()
    book_status_by_path = {}
    local manager = {}

    manager.db_conn = {
        prepare = function(_self, sql)
            manager.sql = sql
            manager.prepare_count = (manager.prepare_count or 0) + 1
            local statement = {
                index = 0,
                bind = function(self, ...)
                    self.bound = { ... }
                    manager.bound = self.bound
                end,
                step = function(self)
                    self.index = self.index + 1
                    return rows[self.index]
                end,
            }
            return statement
        end,
    }

    function manager:openDbConnection()
        self.opened = true
    end

    return manager
end

local function setBookStatus(path, status)
    book_status_by_path[path] = status
end

local function book(path, filename, title, authors, series, series_index, keywords)
    return {
        path,
        filename,
        title,
        authors,
        series,
        series_index,
        keywords,
    }
end

local function findFacet(results, value)
    for _, result in ipairs(results) do
        if result[1] == value then
            return result
        end
    end
end

test("getMatchingFiles builds SQL from filter state trail in order", function()
    local state = FilterState.new("/books")
    FilterState.addFilter(state, "authors", "A/B % [x] *")
    FilterState.addFilter(state, "keywords", "award")
    FilterState.addFilter(state, "series", "Foo")

    local manager = makeManager({
        book("/books/a.epub", "a.epub", "A", "A/B % [x] *", "Foo", "12", "award"),
    })
    local files = MetadataSource.getMatchingFiles(manager, "/books", state, 10)

    assertTruthy(manager.opened)
    assertContains(manager.sql, "directory glob ?")
    assertContains(manager.sql, "instr('\n'||authors||'\n', ?) > 0")
    assertContains(manager.sql, "instr('\n'||keywords||'\n', ?) > 0")
    assertContains(manager.sql, "series=?")
    assertContains(manager.sql, "limit 10")
    assertEqual(manager.bound[1], "/books/*")
    assertEqual(manager.bound[2], "\nA/B % [x] *\n")
    assertEqual(manager.bound[3], "\naward\n")
    assertEqual(manager.bound[4], "Foo")
    assertEqual(#files, 1)
    assertEqual(files[1].series_index, 12)
end)

test("getMatchingFiles uses is-null SQL for missing facet values", function()
    local state = FilterState.new("/books")
    FilterState.addFilter(state, "series", false)

    local manager = makeManager({})
    MetadataSource.getMatchingFiles(manager, "/books", state)

    assertContains(manager.sql, "series is NULL")
    assertEqual(#manager.bound, 1)
    assertEqual(manager.bound[1], "/books/*")
end)

test("getMatchingFiles ignores non-numeric limits", function()
    local manager = makeManager({
        book("/books/a.epub", "a.epub", "A", "Alice", "Foo", "1", "tag"),
    })

    local ok, err = pcall(function()
        MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"), "not a number")
    end)

    assertTruthy(ok, err)
    assertEqual(manager.sql:find("limit", 1, true), nil)
end)

test("getMatchingFiles escapes glob metacharacters in base directory", function()
    local manager = makeManager({})
    MetadataSource.getMatchingFiles(manager, "/books/[drafts]?*", FilterState.new("/books/[drafts]?*"))

    assertEqual(manager.bound[1], "/books/[[]drafts[]][?][*]/*")
end)

test("getMatchingFiles normalizes trailing slash in base directory glob", function()
    local manager = makeManager({})
    MetadataSource.getMatchingFiles(manager, "/books/", FilterState.new("/books/"))

    assertEqual(manager.bound[1], "/books/*")
end)

test("getMatchingFiles filters out missing files and unsupported providers", function()
    local manager = makeManager({
        book("/books/ok.epub", "ok.epub", "OK", "Alice", "Foo", "1", "tag"),
        book("/books/missing.epub", "missing.epub", "Missing", "Alice", "Foo", "2", "tag"),
        book("/books/no_provider.epub", "no_provider.epub", "No Provider", "Alice", "Foo", "3", "tag"),
    })
    local files = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"))

    assertEqual(#files, 1)
    assertEqual(files[1][1], "/books/ok.epub")
end)

test("getMatchingFiles filters out supported non-book formats", function()
    local manager = makeManager({
        book("/books/ok.epub", "ok.epub", "OK", "Alice", "Foo", "1", "tag"),
        book("/books/notes.txt", "notes.txt", "Notes", nil, nil, nil, nil),
        book("/books/readme.md", "readme.md", "Readme", nil, nil, nil, nil),
        book("/books/script.sh", "script.sh", "Script", nil, nil, nil, nil),
    })
    local files = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"))

    assertEqual(#files, 1)
    assertEqual(files[1][1], "/books/ok.epub")
end)

test("getMatchingFiles accepts book-like multipart extensions", function()
    local manager = makeManager({
        book("/books/a.fb2.zip", "a.fb2.zip", "A", "Alice", "Foo", "1", "tag"),
        book("/books/b.rtf.zip", "b.rtf.zip", "B", "Bob", "Bar", "2", "tag"),
        book("/books/c.zip", "c.zip", "C", "Carol", "Baz", "3", "tag"),
    })
    local files = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"))

    assertEqual(#files, 2)
    assertEqual(files[1][1], "/books/a.fb2.zip")
    assertEqual(files[2][1], "/books/b.rtf.zip")
end)

test("getMatchingFiles applies status filters after SQL and validity checks", function()
    local manager = makeManager({
        book("/books/new.epub", "new.epub", "New", "Alice", "Foo", "1", "tag"),
        book("/books/reading.epub", "reading.epub", "Reading", "Alice", "Foo", "2", "tag"),
        book("/books/finished.epub", "finished.epub", "Finished", "Alice", "Foo", "3", "tag"),
    })
    setBookStatus("/books/new.epub", "new")
    setBookStatus("/books/reading.epub", "reading")
    setBookStatus("/books/finished.epub", "complete")

    local reading = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"), nil, {
        filter = "reading",
    })
    local finished = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"), nil, {
        filter = "finished",
    })

    assertEqual(#reading, 1)
    assertEqual(reading[1][1], "/books/reading.epub")
    assertEqual(#finished, 1)
    assertEqual(finished[1][1], "/books/finished.epub")
end)

test("getMatchingFiles caches status filters independently", function()
    local manager = makeManager({
        book("/books/new.epub", "new.epub", "New", "Alice", "Foo", "1", "tag"),
        book("/books/reading.epub", "reading.epub", "Reading", "Alice", "Foo", "2", "tag"),
    })
    setBookStatus("/books/new.epub", "new")
    setBookStatus("/books/reading.epub", "reading")

    local unread = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"), nil, {
        filter = "unread",
    })
    local reading = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"), nil, {
        filter = "reading",
    })
    local unread_again = MetadataSource.getMatchingFiles(manager, "/books", FilterState.new("/books"), nil, {
        filter = "unread",
    })

    assertEqual(#unread, 1)
    assertEqual(unread[1][1], "/books/new.epub")
    assertEqual(#reading, 1)
    assertEqual(reading[1][1], "/books/reading.epub")
    assertEqual(#unread_again, 1)
    assertEqual(manager.prepare_count, 2)
end)

test("getFacetValues groups multi-value facets and marks selected values", function()
    local state = FilterState.new("/books")
    FilterState.addFilter(state, "authors", "Alice")

    local original = MetadataSource.getMatchingFiles
    MetadataSource.getMatchingFiles = function()
        return {
            { authors = "Alice\nBob" },
            { authors = "Bob\nCarol" },
            { authors = nil },
        }
    end

    local ok, results = pcall(function()
        return MetadataSource.getFacetValues({}, "/books", "authors", state)
    end)
    MetadataSource.getMatchingFiles = original
    if not ok then
        error(results)
    end

    assertEqual(findFacet(results, "Alice")[2], 1)
    assertEqual(findFacet(results, "Alice").selected, true)
    assertEqual(findFacet(results, "Bob")[2], 2)
    assertEqual(findFacet(results, "Carol")[2], 1)
    assertEqual(findFacet(results, false)[2], 1)
end)

test("getFacetValues groups series as a single-value facet", function()
    local original = MetadataSource.getMatchingFiles
    MetadataSource.getMatchingFiles = function()
        return {
            { series = "Foo" },
            { series = "Foo" },
            { series = nil },
        }
    end

    local ok, results = pcall(function()
        return MetadataSource.getFacetValues({}, "/books", "series", FilterState.new("/books"))
    end)
    MetadataSource.getMatchingFiles = original
    if not ok then
        error(results)
    end

    assertEqual(findFacet(results, "Foo")[2], 2)
    assertEqual(findFacet(results, false)[2], 1)
end)

test("getFacetValuesWithCount reuses matching files across dimensions", function()
    local manager = makeManager({
        book("/books/a.epub", "a.epub", "A", "Alice\nBob", "Foo", "1", "tag"),
        book("/books/b.epub", "b.epub", "B", "Bob", "Bar", "2", "tag"),
    })
    local state = FilterState.new("/books")

    local authors, author_count = MetadataSource.getFacetValuesWithCount(manager, "/books", "authors", state)
    local series, series_count = MetadataSource.getFacetValuesWithCount(manager, "/books", "series", state)

    assertEqual(author_count, 2)
    assertEqual(series_count, 2)
    assertEqual(findFacet(authors, "Bob")[2], 2)
    assertEqual(findFacet(series, "Foo")[2], 1)
    assertEqual(manager.prepare_count, 1)
end)

test("getFacetValuesWithCount applies status filter before grouping", function()
    local manager = makeManager({
        book("/books/a.epub", "a.epub", "A", "Alice\nBob", "Foo", "1", "tag"),
        book("/books/b.epub", "b.epub", "B", "Bob", "Bar", "2", "tag"),
    })
    setBookStatus("/books/a.epub", "reading")
    setBookStatus("/books/b.epub", "complete")

    local authors, count = MetadataSource.getFacetValuesWithCount(
        manager,
        "/books",
        "authors",
        FilterState.new("/books"),
        { filter = "reading" }
    )

    assertEqual(count, 1)
    assertEqual(findFacet(authors, "Alice")[2], 1)
    assertEqual(findFacet(authors, "Bob")[2], 1)
end)

test("getMatchingFiles returns a fresh array wrapper for cached files", function()
    local manager = makeManager({
        book("/books/a.epub", "a.epub", "A", "Alice", "Foo", "1", "tag"),
        book("/books/b.epub", "b.epub", "B", "Bob", "Bar", "2", "tag"),
    })
    local state = FilterState.new("/books")

    local first = MetadataSource.getMatchingFiles(manager, "/books", state)
    table.remove(first, 1)
    local second = MetadataSource.getMatchingFiles(manager, "/books", state)

    assertEqual(#first, 1)
    assertEqual(#second, 2)
    assertEqual(second[1][1], "/books/a.epub")
    assertEqual(manager.prepare_count, 1)
end)

test("getMatchingFiles caches file validity across uncached limited queries", function()
    local manager = makeManager({
        book("/books/a.epub", "a.epub", "A", "Alice", "Foo", "1", "tag"),
        book("/books/no_provider.epub", "no_provider.epub", "No Provider", "Alice", "Foo", "2", "tag"),
        book("/books/notes.txt", "notes.txt", "Notes", nil, nil, nil, nil),
    })
    local state = FilterState.new("/books")

    local first = MetadataSource.getMatchingFiles(manager, "/books", state, 10)
    local second = MetadataSource.getMatchingFiles(manager, "/books", state, 10)

    assertEqual(#first, 1)
    assertEqual(#second, 1)
    assertEqual(manager.prepare_count, 2)
    assertEqual(file_check_counts.attributes["/books/a.epub"], 1)
    assertEqual(file_check_counts.providers["/books/a.epub"], 1)
    assertEqual(file_check_counts.attributes["/books/no_provider.epub"], 1)
    assertEqual(file_check_counts.providers["/books/no_provider.epub"], 1)
    assertEqual(file_check_counts.attributes["/books/notes.txt"], nil)
    assertEqual(file_check_counts.providers["/books/notes.txt"], nil)
end)

test("getFacetValues can exclude a dimension without mutating original state", function()
    local state = FilterState.new("/books")
    FilterState.addFilter(state, "authors", "Alice")
    FilterState.addFilter(state, "series", "Foo")

    local captured_state
    local original = MetadataSource.getMatchingFiles
    MetadataSource.getMatchingFiles = function(_book_info_manager, _base_dir, query_state)
        captured_state = query_state
        return {}
    end

    local ok, err = pcall(function()
        MetadataSource.getFacetValues({}, "/books", "series", state, {
            exclude_dimension = "series",
        })
    end)
    MetadataSource.getMatchingFiles = original
    if not ok then
        error(err)
    end

    assertEqual(#captured_state.trail, 1)
    assertEqual(captured_state.trail[1].dimension, "authors")
    assertEqual(captured_state.trail[1].value, "Alice")
    assertEqual(#state.trail, 2)
    assertTruthy(state.selected.series.Foo)
end)

test("getAllFacetValues requests every known dimension in configured order", function()
    local seen = {}
    local original = MetadataSource.getFacetValues
    MetadataSource.getFacetValues = function(_book_info_manager, _base_dir, dimension)
        seen[#seen + 1] = dimension
        return { dimension }
    end

    local ok, results = pcall(function()
        return MetadataSource.getAllFacetValues({}, "/books", FilterState.new("/books"))
    end)
    MetadataSource.getFacetValues = original
    if not ok then
        error(results)
    end

    assertEqual(seen[1], "authors")
    assertEqual(seen[2], "series")
    assertEqual(seen[3], "keywords")
    assertEqual(results.authors[1], "authors")
    assertEqual(results.series[1], "series")
    assertEqual(results.keywords[1], "keywords")
end)

run()
