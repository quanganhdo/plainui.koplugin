-- SPDX-FileCopyrightText: 2026 Anh Do
-- SPDX-License-Identifier: MIT

local TabOptionPresenter = {}

local _ = require("gettext")

local FILTER_VALUES = {
    books = { "legacy", "all", "unread", "reading", "finished" },
    metadata = { "all", "unread", "reading", "finished" },
}

local SORT_VALUES = {
    books = { "legacy", "recent", "title", "progress" },
    metadata = { "name", "book_count" },
}

function TabOptionPresenter.getFieldValues(tab_key, field)
    if field == "filter" then
        return FILTER_VALUES[tab_key == "books" and "books" or "metadata"]
    end
    return SORT_VALUES[tab_key == "books" and "books" or "metadata"]
end

function TabOptionPresenter.getOptionField(tab_key, field)
    if field == "filter" then
        return "filter"
    end
    return tab_key == "books" and "sort" or "folder_sort"
end

function TabOptionPresenter.getSummaryLabel(field)
    return field == "filter" and _("Book status") or _("Sort by")
end

function TabOptionPresenter.getFilterLabel(value)
    local labels = {
        legacy = _("KOReader setting"),
        all = _("All"),
        unread = _("Unread"),
        reading = _("Reading"),
        finished = _("Finished"),
    }
    return labels[value] or labels.all
end

function TabOptionPresenter.getSortLabel(value, tab_key)
    local name_labels = {
        authors = _("Author name"),
        series = _("Series title"),
        tags = _("Tag name"),
    }
    local labels = {
        legacy = _("KOReader setting"),
        recent = _("Last read"),
        title = _("Title"),
        progress = _("Progress"),
        name = name_labels[tab_key] or _("Name"),
        book_count = _("Number of books"),
    }
    return labels[value] or labels.name
end

function TabOptionPresenter.getValueLabel(tab_key, field, value)
    if field == "filter" then
        return TabOptionPresenter.getFilterLabel(value)
    end
    return TabOptionPresenter.getSortLabel(value, tab_key)
end

return TabOptionPresenter
