package.path = package.path .. ";./?.lua;./?/init.lua"
local Helper = require("tests.test_helper")
local test, run = Helper.newSuite()
local equal, truthy = Helper.assertEqual, Helper.assertTruthy
local Container = {}
function Container:extend(t)
    t.__index = t
    function t:new(options)
        setmetatable(options, self)
        options:init()
        return options
    end
    return t
end
package.loaded["ui/widget/container/inputcontainer"] = Container
package.loaded["ui/geometry"] = { new = function(_, t) return t end }
package.loaded["ui/gesturerange"] = { new = function(_, t) return t end }
package.loaded["device"] = { screen = {
    scaleBySize = function(_, n) return n end,
    getWidth = function() return 600 end,
    getHeight = function() return 800 end,
} }
package.loaded["ui/font"] = { getFace = function() return {} end }
package.loaded["ui/size"] = { item = { height_big = 40 } }
package.loaded["ffi/blitbuffer"] = { COLOR_WHITE = 0, COLOR_DARK_GRAY = 1 }
package.loaded["ffi/util"] = { template = function(t, value) return (t:gsub("%%1", value)) end }
package.loaded["gettext"] = function(t) return t end
package.loaded["ui/widget/textwidget"] = { new = function(_, t)
    function t:getSize() return { w = #self.text * 6, h = 16 } end
    function t:paintTo(_, x, y) self.x, self.y = x, y end
    function t:free() self.freed = true end
    return t
end }
local Footer = require("modules.reader.return_footer")
local function fixture()
    local history = { back = 105, forward = 200 }
    function history:getDestinations() return self.back, self.forward end
    function history:getPageLabel(loc) return loc and tostring(loc) end
    function history:goBack() self.action = "back" end
    function history:goForward() self.action = "forward" end
    function history:stayHere() self.action = "stay" end
    local footer = Footer:new{ history = history }
    footer:paintTo({ paintRect = function() end }, 0, 756)
    return footer, history
end

test("footer uses compact labels and keeps control positions fixed", function()
    local footer, history = fixture()
    equal(footer.labels[1].text, "← Page 105")
    equal(footer.labels[2].text, "Page 200 →")
    equal(footer.labels[3].text, "Stay here")
    for _, label in ipairs(footer.labels) do equal(label.bold, true) end
    local back_x, stay_x = footer.labels[1].x, footer.labels[3].x
    equal(back_x, 24)
    equal(stay_x + footer.labels[3]:getSize().w, 576)
    equal(footer.labels[2].x + footer.labels[2]:getSize().w / 2, 300)
    history.forward = nil
    footer:paintTo({ paintRect = function() end }, 0, 756)
    equal(footer.labels[2].text, "")
    equal(footer.labels[1].x, back_x)
    equal(footer.labels[3].x, stay_x)
    footer:onCloseWidget()
end)

test("tap slots invoke current destinations and consume an empty center", function()
    local footer, history = fixture()
    equal(footer:onTapPlainReturnFooter(nil, { pos = { x = 10 } }), true)
    equal(history.action, "back")
    footer:onTapPlainReturnFooter(nil, { pos = { x = 300 } })
    equal(history.action, "forward")
    history.forward, history.action = nil, nil
    equal(footer:onTapPlainReturnFooter(nil, { pos = { x = 300 } }), true)
    equal(history.action, nil)
    footer:onTapPlainReturnFooter(nil, { pos = { x = 590 } })
    equal(history.action, "stay")
    truthy(footer:onIgnorePlainReturnFooter())
    footer:onCloseWidget()
end)

run()
