-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local datetime = require("datetime")
local ffiUtil = require("ffi/util")
local _ = require("gettext")

local HistorySort = {}

function HistorySort.createCollate(history, ui)
    -- Rebuild on each list refresh: history changes while KOReader is running.
    -- File access times can instead reflect copying or extracting book covers.
    local times = {}
    for _, entry in ipairs(history) do
        times[entry.file] = math.max(times[entry.file] or 0, entry.time)
    end

    local titles = {}
    local function getPath(item)
        return item.path or item.file or ""
    end
    local function getTitle(item)
        local path = getPath(item)
        if titles[path] == nil then
            local props = item.doc_props
            if not props and item.is_file and ui and ui.bookinfo then
                props = ui.bookinfo:getDocProps(path)
            end
            titles[path] = props and (props.display_title or props.title) or item.text or path
        end
        return titles[path]
    end

    return {
        text = _("last read date"),
        can_collate_mixed = true,
        init_sort_func = function()
            return function(a, b)
                local a_path, b_path = getPath(a), getPath(b)
                local a_time, b_time = times[a_path] or 0, times[b_path] or 0
                if a_time ~= b_time then
                    return a_time > b_time
                end
                local a_title, b_title = getTitle(a), getTitle(b)
                if ffiUtil.strcoll(a_title, b_title) then
                    return true
                elseif ffiUtil.strcoll(b_title, a_title) then
                    return false
                end
                return a_path < b_path
            end
        end,
        mandatory_func = function(item)
            local time = times[getPath(item)]
            return time and datetime.secondsToDateTime(time) or "–"
        end,
    }
end

return HistorySort
