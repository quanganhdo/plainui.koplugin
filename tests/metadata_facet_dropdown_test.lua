package.path = "./?.lua;./?/init.lua;" .. package.path

local TestHelper = require("tests.test_helper")

local assertEqual = TestHelper.assertEqual
local test, run = TestHelper.newSuite()

local real_virtual_path = require("modules.virtual_path")
local metadata_source_stub = {}
metadata_source_stub.getFacetValuesWithCount = function(book_info_manager, base_dir, meta_name, filter_state)
    local values = metadata_source_stub.getMatchingMetadataValues
        and metadata_source_stub.getMatchingMetadataValues(book_info_manager, base_dir, meta_name, filter_state)
        or {}
    local files = metadata_source_stub.getMatchingFiles
        and metadata_source_stub.getMatchingFiles(book_info_manager, base_dir, filter_state)
        or {}
    return values, #files
end
metadata_source_stub.getStatusFilterCounts = function()
    return {
        all = 4,
        unread = 1,
        reading = 2,
        finished = 1,
    }
end
local ui_manager_stub = {
    shown = {},
    closed = {},
    show = function(self, dialog)
        table.insert(self.shown, dialog)
    end,
    close = function(self, dialog)
        table.insert(self.closed, dialog)
    end,
}
local file_manager_stub = {}
local book_info_manager_stub = {}
local saved_loaded = {
    bookinfomanager = package.loaded.bookinfomanager,
    buttondialog = package.loaded["ui/widget/buttondialog"],
    ffi_util = package.loaded["ffi/util"],
    filemanager = package.loaded["apps/filemanager/filemanager"],
    metadata_source = package.loaded["modules.metadata_source"],
    size = package.loaded["ui/size"],
    uimanager = package.loaded["ui/uimanager"],
    virtual_path = package.loaded["modules.virtual_path"],
    gettext = package.loaded.gettext,
}

package.loaded["ui/widget/buttondialog"] = {
    new = function(_self, args)
        return args
    end,
}
package.loaded["ffi/util"] = {
    strcoll = function(a, b)
        return a < b
    end,
}
package.loaded["apps/filemanager/filemanager"] = file_manager_stub
package.loaded["bookinfomanager"] = book_info_manager_stub
package.loaded["modules.metadata_source"] = metadata_source_stub
package.loaded["ui/size"] = {
    padding = {
        default = 5,
        large = 10,
    },
}
package.loaded["ui/uimanager"] = ui_manager_stub
package.loaded["modules.virtual_path"] = real_virtual_path
package.loaded.gettext = function(text)
    return text
end
package.loaded["modules.metadata_facet_dropdown"] = nil

local MetadataFacetDropdown = require("modules.metadata_facet_dropdown")

package.loaded["ui/widget/buttondialog"] = saved_loaded.buttondialog
package.loaded["ffi/util"] = saved_loaded.ffi_util
package.loaded["apps/filemanager/filemanager"] = saved_loaded.filemanager
package.loaded["modules.metadata_source"] = saved_loaded.metadata_source
package.loaded["ui/size"] = saved_loaded.size
package.loaded["ui/uimanager"] = saved_loaded.uimanager
package.loaded["modules.virtual_path"] = saved_loaded.virtual_path
package.loaded.gettext = saved_loaded.gettext
package.loaded.bookinfomanager = book_info_manager_stub
local saved_reader_settings = G_reader_settings

local function virtualPath(...)
    return table.concat({ "/books", real_virtual_path.ROOT_SYMBOL, ... }, "/")
end

local function resetUi()
    ui_manager_stub.shown = {}
    ui_manager_stub.closed = {}
end

local function findButtonRow(buttons, text)
    for index, row in ipairs(buttons) do
        if row[1] and row[1].text == text then
            return row, index
        end
    end
end

test("second dropdown treats same-count values as disabled and moves them last", function()
    local values = {
        { "Narrow", 2 },
        { "Same", 4 },
        { "Selected", 1, selected = true },
        { "Wider", 5 },
        { "Also narrow", 3 },
    }

    local useful_values, non_narrowing_values =
        MetadataFacetDropdown._test.splitValuesByNarrowing(values, 4)

    assertEqual(#useful_values, 2)
    assertEqual(useful_values[1][1], "Narrow")
    assertEqual(useful_values[2][1], "Also narrow")

    assertEqual(#non_narrowing_values, 2)
    assertEqual(non_narrowing_values[1][1], "Same")
    assertEqual(non_narrowing_values[2][1], "Wider")
end)

test("show does nothing when path is still on an active dimension", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.AUTHOR_SYMBOL, "Alice", real_virtual_path.KEYWORD_SYMBOL),
        },
    }

    MetadataFacetDropdown.show(file_manager, {})

    assertEqual(#ui_manager_stub.shown, 0)
end)

test("show omits dimensions whose values are already selected", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.AUTHOR_SYMBOL, "Alice"),
        },
    }
    metadata_source_stub.getMatchingMetadataValues = function(_book_info_manager, _base_dir, dimension)
        if dimension == "authors" then
            return {
                { "Alice", 4, selected = true },
            }
        elseif dimension == "series" then
            return {
                { "Foo", 2 },
                { "Already selected", 1, selected = true },
            }
        elseif dimension == "keywords" then
            return {
                { "award", 1 },
                { "Already selected", 1, selected = true },
            }
        end
        return {}
    end

    MetadataFacetDropdown.show(file_manager, {})

    local buttons = ui_manager_stub.shown[1].buttons
    assertEqual(#buttons, 4)
    assertEqual(buttons[1][1].text, "Book status")
    assertEqual(buttons[1][2].text, "All")
    assertEqual(#buttons[2], 0)
    assertEqual(buttons[3][1].text, "Series")
    assertEqual(buttons[3][2].text, "1")
    assertEqual(buttons[4][1].text, "Tags")
    assertEqual(buttons[4][2].text, "1")
end)

test("show counts available dimensions without sorting values", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.AUTHOR_SYMBOL, "Alice"),
        },
    }
    metadata_source_stub.getMatchingMetadataValues = function()
        return {
            { "Zed", 1 },
            { "Alpha", 1 },
            { "Selected", 1, selected = true },
        }
    end

    local original_sort = table.sort
    table.sort = function()
        error("unexpected sort")
    end
    local ok, err = pcall(function()
        MetadataFacetDropdown.show(file_manager, {})
    end)
    table.sort = original_sort
    if not ok then
        error(err)
    end

    local buttons = ui_manager_stub.shown[1].buttons
    assertEqual(#buttons, 5)
    assertEqual(buttons[3][2].text, "2")
    assertEqual(buttons[4][2].text, "2")
    assertEqual(buttons[5][2].text, "2")
end)

test("show displays no relevant filters row when every available value is selected", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.AUTHOR_SYMBOL, "Alice"),
        },
    }
    metadata_source_stub.getMatchingMetadataValues = function()
        return {
            { "Selected", 1, selected = true },
        }
    end

    MetadataFacetDropdown.show(file_manager, {})

    local buttons = ui_manager_stub.shown[1].buttons
    assertEqual(#buttons, 3)
    assertEqual(buttons[3][1].text, "No relevant filters")
    assertEqual(buttons[3][1].enabled, false)
end)

test("show opens filter values from leaf dropdown", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.SERIES_SYMBOL, "Foo"),
            refreshPath = function() end,
        },
    }
    G_reader_settings = {
        readSetting = function(_self, key)
            if key == "plainui_tab_view_options" then
                return {
                    series = {
                        filter = "reading",
                        folder_sort = "book_count",
                    },
                }
            end
        end,
        saveSetting = function() end,
    }
    metadata_source_stub.getMatchingMetadataValues = function()
        return {}
    end

    local ok, err = pcall(function()
        MetadataFacetDropdown.show(file_manager, {})
        ui_manager_stub.shown[1].buttons[1][1].callback()
    end)
    G_reader_settings = saved_reader_settings
    if not ok then
        error(err)
    end

    local buttons = ui_manager_stub.shown[2].buttons
    assertEqual(buttons[1][1].text, "Back")
    local row = findButtonRow(buttons, "\u{25c9}")
    assertEqual(row[2].text, "Reading")
    assertEqual(row[3].text, "2")
end)

test("filter selection saves tab option and refreshes current leaf", function()
    resetUi()
    local saved_options = {}
    local refreshed = 0
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.KEYWORD_SYMBOL, "award"),
            refreshPath = function()
                refreshed = refreshed + 1
            end,
        },
    }
    G_reader_settings = {
        readSetting = function(_self, key)
            if key == "plainui_tab_view_options" then
                return saved_options
            end
        end,
        saveSetting = function(_self, key, value)
            if key == "plainui_tab_view_options" then
                saved_options = value
            end
        end,
    }
    metadata_source_stub.getMatchingMetadataValues = function()
        return {}
    end

    local ok, err = pcall(function()
        MetadataFacetDropdown.show(file_manager, {})
        ui_manager_stub.shown[1].buttons[1][1].callback()
        findButtonRow(ui_manager_stub.shown[2].buttons, "\u{25ef}")[2].callback()
    end)
    G_reader_settings = saved_reader_settings
    if not ok then
        error(err)
    end

    assertEqual(saved_options.tags.filter, "unread")
    assertEqual(refreshed, 1)
    assertEqual(#ui_manager_stub.shown, 3)
    assertEqual(ui_manager_stub.shown[3].buttons[2][1].text, "\u{25ef}")
    assertEqual(ui_manager_stub.shown[3].buttons[3][1].text, "\u{25c9}")
    assertEqual(ui_manager_stub.shown[3].buttons[3][2].text, "Unread")
end)

test("showValues sorts values, hides selected values, and disables non-narrowing rows", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.AUTHOR_SYMBOL, "Alice"),
            changeToPath = function() end,
        },
    }
    metadata_source_stub.getMatchingMetadataValues = function()
        return {
            { "Zed", 1 },
            { "Same", 4 },
            { false, 1 },
            { "Alpha", 1 },
            { "Selected", 1, selected = true },
        }
    end
    metadata_source_stub.getMatchingFiles = function()
        return {
            { "/books/a.epub" },
            { "/books/b.epub" },
            { "/books/c.epub" },
            { "/books/d.epub" },
        }
    end

    MetadataFacetDropdown.showValues(file_manager, {}, {
        key = "authors",
        label = "Authors",
    })

    local buttons = ui_manager_stub.shown[1].buttons
    assertEqual(#buttons, 5)
    assertEqual(buttons[1][1].text, "Back")
    assertEqual(buttons[2][1].text, "Alpha")
    assertEqual(buttons[2][1].enabled, true)
    assertEqual(buttons[3][1].text, "Zed")
    assertEqual(buttons[3][1].enabled, true)
    assertEqual(buttons[4][1].text, real_virtual_path.EMPTY_VALUE_SYMBOL)
    assertEqual(buttons[4][1].enabled, true)
    assertEqual(buttons[5][1].text, "Same")
    assertEqual(buttons[5][1].enabled, false)
end)

test("showValues uses facet result count without fetching matching files again", function()
    resetUi()
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.AUTHOR_SYMBOL, "Alice"),
            changeToPath = function() end,
        },
    }
    metadata_source_stub.getFacetValuesWithCount = function()
        return {
            { "Narrow", 1 },
            { "Same", 4 },
        }, 4
    end
    metadata_source_stub.getMatchingFiles = function()
        error("unexpected matching files fetch")
    end

    MetadataFacetDropdown.showValues(file_manager, {}, {
        key = "authors",
        label = "Authors",
    })

    local buttons = ui_manager_stub.shown[1].buttons
    assertEqual(buttons[2][1].text, "Narrow")
    assertEqual(buttons[2][1].enabled, true)
    assertEqual(buttons[3][1].text, "Same")
    assertEqual(buttons[3][1].enabled, false)
end)

test("show passes tab options to facet counts", function()
    resetUi()
    local captured_options
    local file_manager = {
        file_chooser = {
            path = virtualPath(real_virtual_path.SERIES_SYMBOL, "Foo"),
        },
    }
    G_reader_settings = {
        readSetting = function(_self, key)
            if key == "plainui_tab_view_options" then
                return {
                    series = {
                        filter = "reading",
                        folder_sort = "book_count",
                    },
                }
            end
        end,
    }
    metadata_source_stub.getFacetValuesWithCount = function(
            _book_info_manager,
            _base_dir,
            _meta_name,
            _filter_state,
            options)
        captured_options = options
        return {}, 0
    end

    local ok, err = pcall(function()
        MetadataFacetDropdown.show(file_manager, {})
    end)
    G_reader_settings = saved_reader_settings
    if not ok then
        error(err)
    end

    assertEqual(captured_options.filter, "reading")
    assertEqual(captured_options.folder_sort, "book_count")
end)

run()
