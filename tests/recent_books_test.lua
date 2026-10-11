package.path = "./?.lua;./?/init.lua;" .. package.path
local Helper = require("tests.test_helper")
local test, run = Helper.newSuite()
local eq, truth = Helper.assertEqual, Helper.assertTruthy
local existing = { ["/current"] = "file", ["/a.epub"] = "file", ["/b.epub"] = "file",
    ["/c.epub"] = "file", ["/d.epub"] = "file", ["/folder"] = "directory" }
local saved_util, saved_lfs = package.loaded["ffi/util"], package.loaded["libs/libkoreader-lfs"]
package.loaded["ffi/util"] = { realpath = function(file) return file == "/current-alias" and "/current" or file end }
package.loaded["libs/libkoreader-lfs"] = { attributes = function(file, field)
    eq(field, "mode"); return existing[file]
end }
local Recent = require("modules.reader.recent_books")
package.loaded["ffi/util"], package.loaded["libs/libkoreader-lfs"] = saved_util, saved_lfs
local function ui(title)
    return { document = { file = "/current-alias" }, bookinfo = { getDocProps = function(_, file, props, no_open)
        eq(props, nil); eq(no_open, true)
        return title and { display_title = title[file] } or nil
    end } }
end
test("recent books exclude current, deleted, missing, disabled, folders, and duplicates", function()
    local history = { { file = "/current", time = 100 }, { file = "/gone", time = 90 },
        { file = "/folder", time = 80 }, { file = "/a.epub", time = 70, dim = true },
        { file = "/d.epub", time = 65, select_enabled = false }, { file = "/b.epub", time = 60 },
        { file = "/b.epub", time = 60 }, { file = "/c.epub", time = 50 } }
    local books = Recent.get(ui(), history)
    eq(#books, 2); eq(books[1].file, "/b.epub"); eq(books[2].file, "/c.epub")
    eq(#history, 8); eq(history[6].text, nil)
end)
test("recent books choose three newest dates with stable ties without mutating history", function()
    local history = { { file = "/d.epub", time = 5 }, { file = "/b.epub", time = 30 },
        { file = "/c.epub", time = 30 }, { file = "/a.epub", time = 40 } }
    local books = Recent.get(ui(), history)
    eq(#books, 3); eq(books[1].file, "/a.epub"); eq(books[2].file, "/b.epub"); eq(books[3].file, "/c.epub")
    eq(history[1].file, "/d.epub")
end)
test("duplicate history entries use the latest date", function()
    local books = Recent.get(ui(), { { file = "/a.epub", time = 1 },
        { file = "/b.epub", time = 20 }, { file = "/a.epub", time = 30 } })
    eq(#books, 2); eq(books[1].file, "/a.epub"); eq(books[2].file, "/b.epub")
end)
test("cached customized titles are normalized with filename fallback", function()
    local books = Recent.get(ui({ ["/a.epub"] = "  Custom\nbook\t title  ", ["/b.epub"] = "   " }),
        { { file = "/a.epub", time = 3 }, { file = "/b.epub", time = 2 }, { file = "/c.epub", time = 1 } })
    eq(books[1].title, "Custom book title"); eq(books[2].title, "b"); eq(books[3].title, "c")
end)
test("only the three displayed books have their metadata read", function()
    local reader, count = ui(), 0
    reader.bookinfo.getDocProps = function(_, _, _, no_open) truth(no_open); count = count + 1 end
    local books = Recent.get(reader, { { file = "/a.epub" }, { file = "/b.epub" },
        { file = "/c.epub" }, { file = "/d.epub" } })
    eq(#books, 3); eq(count, 3)
end)
test("empty history and metadata-free readers return safely", function()
    eq(#Recent.get(ui(), {}), 0)
    local books = Recent.get({document={file="/current"}}, { { file = "/a.epub" } })
    eq(#books, 1); eq(books[1].title, "a")
end)
run()
