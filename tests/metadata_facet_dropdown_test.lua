package.path = "./?.lua;./?/init.lua;" .. package.path

local TestHelper = require("tests.test_helper")

local assertEqual = TestHelper.assertEqual
local test, run = TestHelper.newSuite()

local saved_loaded = {
    buttondialog = package.loaded["ui/widget/buttondialog"],
    ffi_util = package.loaded["ffi/util"],
    filemanager = package.loaded["apps/filemanager/filemanager"],
    metadata_source = package.loaded["modules.metadata_source"],
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
package.loaded["apps/filemanager/filemanager"] = {}
package.loaded["modules.metadata_source"] = {}
package.loaded["ui/uimanager"] = {}
package.loaded["modules.virtual_path"] = {}
package.loaded.gettext = function(text)
    return text
end
package.loaded["modules.metadata_facet_dropdown"] = nil

local MetadataFacetDropdown = require("modules.metadata_facet_dropdown")

package.loaded["ui/widget/buttondialog"] = saved_loaded.buttondialog
package.loaded["ffi/util"] = saved_loaded.ffi_util
package.loaded["apps/filemanager/filemanager"] = saved_loaded.filemanager
package.loaded["modules.metadata_source"] = saved_loaded.metadata_source
package.loaded["ui/uimanager"] = saved_loaded.uimanager
package.loaded["modules.virtual_path"] = saved_loaded.virtual_path
package.loaded.gettext = saved_loaded.gettext

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

run()
