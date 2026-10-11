-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local RecentBooks = {}

function RecentBooks.get(ui, history)
    history = history or require("readhistory").hist
    local current = ui.document and ui.document.file
    current = current and (ffiUtil.realpath(current) or current)
    local candidates, seen = {}, {}
    for index, entry in ipairs(history) do
        local file = entry.file
        if type(file) == "string" and file ~= current and not entry.dim and entry.select_enabled ~= false then
            local candidate = seen[file]
            if candidate then
                candidate.time = math.max(candidate.time, entry.time or 0)
            else
                candidate = { file = file, time = entry.time or 0, index = index }
                seen[file] = candidate
                candidates[#candidates + 1] = candidate
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        return a.index < b.index
    end)
    local books = {}
    for _, candidate in ipairs(candidates) do
        local file = candidate.file
        if lfs.attributes(file, "mode") == "file" then
            -- Read cached/customized metadata without loading or rendering a book.
            local props = ui.bookinfo and ui.bookinfo:getDocProps(file, nil, true)
            local title = props and (props.display_title or props.title)
            title = type(title) == "string" and title:gsub("%s+", " "):match("^%s*(.-)%s*$") or nil
            if not title or title == "" then
                title = (file:match("[^/]+$") or file):gsub("%.[^.]+$", "")
            end
            books[#books + 1] = { file = file, title = title }
            if #books == 3 then break end
        end
    end
    return books
end

return RecentBooks
