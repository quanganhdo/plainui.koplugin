local suites = {
    "tests/virtual_path_test.lua",
    "tests/filter_state_test.lua",
    "tests/virtual_leaf_test.lua",
    "tests/tab_view_options_test.lua",
    "tests/metadata_sort_test.lua",
    "tests/history_sort_test.lua",
    "tests/recent_books_test.lua",
    "tests/metadata_source_test.lua",
    "tests/metadata_facet_dropdown_test.lua",
    "tests/reader_integration_test.lua",
    "tests/typography_profiles_test.lua",
    "tests/bottom_navigation_test.lua",
    "tests/more_actions_test.lua",
    "tests/navigation_history_test.lua",
    "tests/navigation_preview_test.lua",
    "tests/return_footer_test.lua",
    "tests/stats_provider_test.lua",
}

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Each suite supplies its own KOReader mocks. Separate Lua processes prevent
-- package.loaded state and installed UI hooks leaking into the next suite.
local interpreter = arg[-1] or "lua"
for _, suite in ipairs(suites) do
    local ok = os.execute(quote(interpreter) .. " " .. quote(suite))
    if ok ~= true and ok ~= 0 then
        io.stderr:write("Failed suite: ", suite, "\n")
        os.exit(1)
    end
end
io.stdout:write(string.format("All %d suites passed.\n", #suites))
