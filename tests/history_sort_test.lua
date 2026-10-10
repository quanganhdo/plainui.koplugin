package.path = "./?.lua;./?/init.lua;" .. package.path

local saved = {}
local stubs = {
    ["ffi/util"] = { strcoll = function(a, b) return a < b end },
    datetime = { secondsToDateTime = function(time) return "date:" .. time end },
    gettext = function(text) return text end,
}
for name, stub in pairs(stubs) do
    saved[name] = package.loaded[name]
    package.loaded[name] = stub
end
local HistorySort = require("modules.history_sort")
for name in pairs(stubs) do
    package.loaded[name] = saved[name]
end

local TestHelper = require("tests.test_helper")
local assertEqual = TestHelper.assertEqual
local test, run = TestHelper.newSuite()

local function book(path, title, access)
    return { path = path, text = path, is_file = true,
        doc_props = { display_title = title }, attr = { access = access } }
end

test("last read follows history despite reset or misleading access times", function()
    local items = {
        book("/old", "Old", 9999),
        book("/unread", "Unread", 99999),
        book("/new", "New", 1),
    }
    local collate = HistorySort.createCollate({
        { file = "/missing", time = 300 },
        { file = "/new", time = 200 },
        { file = "/old", time = 100 },
    })
    table.sort(items, collate.init_sort_func())
    assertEqual(items[1].path, "/new")
    assertEqual(items[2].path, "/old")
    assertEqual(items[3].path, "/unread")
    assertEqual(collate.mandatory_func(items[1]), "date:200")
    assertEqual(collate.mandatory_func(items[3]), "–")
end)

test("equal history times and unread books sort by title then path", function()
    local items = {
        book("/z-read", "Beta", 0),
        book("/z-unread", "Alpha", 0),
        book("/a-read", "Alpha", 0),
        book("/a-unread", "Alpha", 0),
        book("/b-unread", "Beta", 0),
    }
    local collate = HistorySort.createCollate({
        { file = "/z-read", time = 100 },
        { file = "/a-read", time = 100 },
    })
    local less = collate.init_sort_func()
    table.sort(items, less)
    local expected = { "/a-read", "/z-read", "/a-unread", "/z-unread", "/b-unread" }
    for index, path in ipairs(expected) do
        assertEqual(items[index].path, path)
        assertEqual(less(items[index], items[index]), false)
    end
end)

test("refresh uses newly read books and changed history timestamps", function()
    local history = { { file = "/old", time = 100 } }
    local old, new = book("/old", "Old", 0), book("/new", "New", 0)
    assertEqual(HistorySort.createCollate(history).init_sort_func()(old, new), true)
    table.insert(history, 1, { file = "/new", time = 200 })
    assertEqual(HistorySort.createCollate(history).init_sort_func()(new, old), true)
    history[2].time = 300
    assertEqual(HistorySort.createCollate(history).init_sort_func()(old, new), true)
end)

test("title fallback handles folders and caches book metadata only for ties", function()
    local lookups = 0
    local ui = { bookinfo = { getDocProps = function(_, path)
        lookups = lookups + 1
        return { display_title = path == "/z" and "Alpha" or "Beta" }
    end } }
    local a = { path = "/z", text = "Z filename", is_file = true }
    local b = { path = "/a", text = "A filename", is_file = true }
    local collate = HistorySort.createCollate({}, ui)
    local less = collate.init_sort_func()
    assertEqual(less(a, b), true)
    assertEqual(less(a, b), true)
    assertEqual(lookups, 2)
    assertEqual(less({ path = "/folder", text = "A folder" }, a), true)
    assertEqual(lookups, 2)
    local dated = HistorySort.createCollate({ { file = "/z", time = 100 } }, ui)
    assertEqual(dated.init_sort_func()(a, b), true)
    assertEqual(lookups, 2)
end)

test("empty history is deterministic and duplicate entries use latest time", function()
    local a, b = book("/a", "Same", 0), book("/b", "Same", 0)
    assertEqual(HistorySort.createCollate({}).init_sort_func()(a, b), true)
    local collate = HistorySort.createCollate({
        { file = "/a", time = 300 },
        { file = "/a", time = 100 },
        { file = "/b", time = 200 },
    })
    assertEqual(collate.init_sort_func()(a, b), true)
end)

run()
