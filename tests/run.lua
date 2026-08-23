package.path = "./?.lua;./?/init.lua;" .. package.path

dofile("tests/virtual_path_test.lua")
dofile("tests/filter_state_test.lua")
dofile("tests/virtual_leaf_test.lua")
dofile("tests/tab_view_options_test.lua")
dofile("tests/metadata_sort_test.lua")
dofile("tests/metadata_source_test.lua")
dofile("tests/metadata_facet_dropdown_test.lua")
dofile("tests/reader_integration_test.lua")
