local WidgetContainer = require("ui/widget/container/widgetcontainer")

local PlainUI = WidgetContainer:extend{
    name = "plainui",
    is_doc_only = false,
    reader_controller = nil,
}

local patched = false

local function applyPatches()
    if patched then
        return
    end
    local UserPatches = require("modules.compat.user_patches")
    UserPatches.initialize{
        file_manager = package.loaded["apps/filemanager/filemanager"],
        reader_ui = package.loaded["apps/reader/readerui"],
    }

    if not UserPatches.isActive("2-author-series.lua") then
        require("modules.author_series")
    end
    if not UserPatches.isActive("2-filemanager-metadata-tabs.lua") then
        require("modules.metadata_tabs")
    end
    if not UserPatches.isActive("2-finished-badge.lua") then
        require("modules.finished_badge")
    end
    if not UserPatches.isActive("2-reading-percentage.lua") then
        require("modules.reading_percentage")
    end
    if not UserPatches.isActive("2-reading-stats-popup.lua") then
        require("modules.reader.reading_stats_popup").install()
    end
    UserPatches.showMigrationNotice()
    patched = true
end

function PlainUI:init()
    applyPatches()
    self.reader_controller = nil
end

function PlainUI:isReaderEnabled()
    if not G_reader_settings then
        return true
    end
    if G_reader_settings.isFalse then
        return not G_reader_settings:isFalse("plainui_reader_enabled")
    end
    if G_reader_settings.readSetting then
        return G_reader_settings:readSetting("plainui_reader_enabled") ~= false
    end
    return true
end

function PlainUI:isRollingReader()
    return self.ui ~= nil and self.ui.rolling ~= nil
end

function PlainUI:getReaderController()
    if not self:isReaderEnabled() or not self:isRollingReader() then
        return nil
    end
    if not self.reader_controller then
        local Controller = require("modules.reader.controller")
        self.reader_controller = Controller.new(self, self.ui)
    end
    return self.reader_controller
end

function PlainUI:onReaderReady()
    local controller = self:getReaderController()
    if controller then
        controller:onReaderReady()
    end
end

function PlainUI:onSetDimensions()
    if self.reader_controller then
        self.reader_controller:onSetDimensions()
    end
end

function PlainUI:stopPlugin()
    if self.reader_controller then
        self.reader_controller:stop()
        self.reader_controller = nil
    end
end

applyPatches()

return PlainUI
