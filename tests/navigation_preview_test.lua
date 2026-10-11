package.path = "./?.lua;./?/init.lua;" .. package.path
local H = require("tests.test_helper")
local test, run = H.newSuite()
local Preview = require("modules.reader.navigation_preview")

local function fixture(cached)
    local requests, canceled, pending, tiles, changes = {}, {}, {}, {}, {}
    local model = Preview.new{
        page = 25, count = 100, width = 600, height = 800,
        manager = {
            scheduleIn = function(_, _, callback) pending[callback] = true end,
            unschedule = function(_, callback) pending[callback] = nil end,
        },
        thumbnail = {
            getPageThumbnail = function(_, page, w, h, batch, callback)
                requests[#requests + 1] = {page = page, batch = batch, callback = callback}
                if cached then callback({page = page}) end
            end,
            cancelPageThumbnailRequests = function(_, batch) canceled[#canceled + 1] = batch end,
        },
        changed = function(page) changes[#changes + 1] = page end,
        rendered = function(tile, page) tiles[#tiles + 1] = {tile = tile, page = page} end,
    }
    return model, requests, canceled, pending, tiles, changes
end

test("slider clamps endpoints and preserves origin", function()
    local m, requests = fixture()
    m:setRatio(-1, true)
    H.assertEqual(m.page, 1)
    H.assertEqual(m:ratio(), 0)
    m:setRatio(2, true)
    H.assertEqual(m.page, 100)
    H.assertEqual(m:ratio(), 1)
    H.assertEqual(m.origin, 25)
    H.assertEqual(#requests, 2)
    m.count = 1
    m:setRatio(0.5, true)
    H.assertEqual(m.page, 1)
    H.assertEqual(m:ratio(), 0)
end)

test("rapid dragging debounces rendering and rejects stale responses", function()
    local m, requests, canceled, pending, tiles = fixture()
    m:request()
    m:setPage(50, false)
    m:setPage(75, false)
    H.assertEqual(#requests, 1)
    H.assertTruthy(pending[m.generate])
    requests[1].callback({old = true})
    H.assertEqual(#tiles, 0)
    H.assertEqual(m.ready, false)
    m.generate()
    H.assertEqual(#requests, 2)
    H.assertEqual(requests[2].page, 75)
    requests[2].callback({new = true})
    H.assertEqual(m.ready, true)
    H.assertEqual(tiles[1].page, 75)
    H.assertTruthy(#canceled > 0)
end)

test("release flushes pending request and synchronous cache hits work", function()
    local m, requests, _, pending = fixture(true)
    m:setPage(60, false)
    H.assertTruthy(pending[m.generate])
    m:setPage(60, true)
    H.assertEqual(pending[m.generate], nil)
    H.assertEqual(#requests, 1)
    H.assertEqual(m.ready, true)
    m:setPage(60, true)
    H.assertEqual(#requests, 1)
end)

test("closing cancels queued work and callbacks cannot revive the preview", function()
    local m, requests, _, pending, tiles = fixture()
    m:request()
    m:setPage(80, false)
    m:close()
    H.assertEqual(pending[m.generate], nil)
    requests[1].callback({})
    m.generate()
    m:setPage(90, true)
    H.assertEqual(#requests, 1)
    H.assertEqual(#tiles, 0)
    H.assertEqual(m.page, 80)
end)

test("failed preview remains unavailable and can be retried", function()
    local m, requests, _, _, tiles = fixture()
    m:request()
    requests[1].callback(nil)
    H.assertEqual(m.ready, false)
    H.assertEqual(#tiles, 1)
    m:setPage(m.page, true)
    H.assertEqual(#requests, 2)
end)

run()
