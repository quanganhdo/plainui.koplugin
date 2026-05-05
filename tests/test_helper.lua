local TestHelper = {}

function TestHelper.assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format(
            "%s: expected %s, got %s",
            message or "assertEqual",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

function TestHelper.assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

function TestHelper.assertContains(text, pattern, message)
    if not text or not text:find(pattern, 1, true) then
        error(string.format(
            "%s: expected %s to contain %s",
            message or "assertContains",
            tostring(text),
            tostring(pattern)
        ), 2)
    end
end

function TestHelper.newSuite()
    local tests = {}

    local function test(name, fn)
        tests[#tests + 1] = { name = name, fn = fn }
    end

    local function run()
        for _, case in ipairs(tests) do
            case.fn()
            io.stdout:write("ok - ", case.name, "\n")
        end
    end

    return test, run
end

return TestHelper
