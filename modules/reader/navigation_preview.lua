-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

-- Preview state deliberately has no access to reader navigation or history.
local Preview = {}
Preview.__index = Preview

function Preview.new(options)
    local self = setmetatable({
        origin = options.page,
        page = options.page,
        count = math.max(1, options.count),
        thumbnail = options.thumbnail,
        manager = options.manager,
        width = options.width,
        height = options.height,
        changed = options.changed,
        rendered = options.rendered,
        rendered_neighbor = options.rendered_neighbor,
        sequence = 0,
        ready = false,
    }, Preview)
    self.generate = function() self:request() end
    return self
end

function Preview:cancel()
    self.manager:unschedule(self.generate)
    self.sequence = self.sequence + 1
    if self.batch then
        self.thumbnail:cancelPageThumbnailRequests(self.batch)
        self.batch = nil
    end
end

function Preview:request()
    if self.closed then return end
    self:cancel()
    local sequence, page = self.sequence, self.page
    self.batch = tostring(self) .. ":" .. sequence
    local batch = self.batch
    self.thumbnail:getPageThumbnail(page, self.width, self.height, batch,
        function(tile)
            if self.closed or sequence ~= self.sequence or page ~= self.page then return end
            self.ready = tile ~= nil
            self.rendered(tile, page)
            -- Render the center first so adjacent pages never delay it.
            if tile then self:requestNeighbors(sequence, page, batch) end
        end)
end

function Preview:requestNeighbors(sequence, page, batch)
    if not self.rendered_neighbor or self.closed or sequence ~= self.sequence then return end
    for _, offset in ipairs{ -1, 1 } do
        local neighbor_page = page + offset
        if neighbor_page >= 1 and neighbor_page <= self.count then
            self.thumbnail:getPageThumbnail(neighbor_page, self.width, self.height, batch,
                function(tile)
                    if self.closed or sequence ~= self.sequence or page ~= self.page then return end
                    self.rendered_neighbor(tile, offset, neighbor_page)
                end)
        end
    end
end

function Preview:setPage(page, immediate)
    if self.closed then return end
    page = math.max(1, math.min(self.count, math.floor(page + 0.5)))
    if page ~= self.page then
        self:cancel()
        self.page, self.ready = page, false
        self.changed(page)
        if immediate then self:request()
        else self.manager:scheduleIn(0.15, self.generate) end
    elseif immediate and not self.ready then
        self:request()
    end
end

function Preview:setRatio(ratio, immediate)
    self:setPage(1 + math.max(0, math.min(1, ratio)) * (self.count - 1), immediate)
end

function Preview:ratio()
    return self.count == 1 and 0 or (self.page - 1) / (self.count - 1)
end

function Preview:close()
    self.closed = true
    self:cancel()
end

return Preview
