package.path = "./?.lua;./?/init.lua;" .. package.path

dofile("tests/virtual_path_test.lua")
dofile("tests/filter_state_test.lua")
dofile("tests/metadata_source_test.lua")
dofile("tests/metadata_facet_dropdown_test.lua")
