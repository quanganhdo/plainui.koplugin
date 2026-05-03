local WidgetContainer = require("ui/widget/container/widgetcontainer")

local PlainUI = WidgetContainer:extend{
    name = "plainui",
    is_doc_only = false,
}

local patched = false

local function applyPatches()
    if patched then
        return
    end
    patched = true

    require("modules.author_series")
    require("modules.metadata_tabs")
    require("modules.finished_badge")
    require("modules.reading_percentage")
end

function PlainUI:init()
    applyPatches()
end

applyPatches()

return PlainUI
