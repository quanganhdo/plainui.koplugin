# Plain UI

Plain UI is a minimal library and reading interface for KOReader focused on quick access to your books and common reading controls.

It adds a Books, Series, Authors, and Tags tab bar, compact device status controls, and a few cover-grid annotations.

## Features

- Use Series, Authors, and Tags views with Mosaic and Detailed list display modes.
- Filter each tab by reading status and choose its sort order.
- Use multiple filters to find exactly what book to read next.
- Quick access from the home screen to dark mode, frontlight, and Wi-Fi.
- Long-press the frontlight icon to toggle the frontlight.
- Long-press the Wi-Fi icon to choose a network.
- Long-press the battery icon to view battery information.
- Swipe down while reading to open a compact toolbar with Lighting, Dark mode, Font, and Reading stats actions. Lighting opens the native frontlight dialog; long-press it to toggle the frontlight. Lighting and Dark mode use the same icons and behavior as the home screen.
- Adjust font, spacing, margins, and alignment from a compact typography panel.
- Swipe up from the bottom edge to preview the book with a centered page preview with the adjacent pages partially visible and a circular progress slider. Drag or tap the slider to browse without changing your reading position; tap the rendered page to jump. A small solid black circle (white in dark mode) marks the page where you opened the preview. Tap it, or release the slider near it, to return the preview to that exact page; the marker stays fixed as you browse. Navigation history is handled by the separate Back/Forward return footer. The bold, underlined chapter name opens KOReader’s Go to page dialog and truncates with a trailing ellipsis to fit between previous- and next-chapter buttons, which browse the preview and are dimmed and inactive when no chapter destination is available. Chapter, Bookmarks, TOC, and Search buttons use the top toolbar’s icon style and sizes. TOC, Bookmarks, and Search sit below the slider on the right, in that order, replacing the percentage, and open their normal KOReader panels; they are no longer in the top toolbar. The page carousel is centered between the title row and bottom bar. A bookmark icon inside the preview’s top-right corner, with top and right padding matching the page-count text’s bottom padding, toggles that previewed page’s bookmark without moving the reader; it is outlined when unsaved, filled when saved, and inactive while the preview loads. Swipe the preview left or right, or tap an adjacent page to bring it to the center. Tap the bold, underlined “Return to p…” label to recenter the preview at its opening page. Tap or swipe up on the chevron at the bottom edge to open KOReader's original settings panel. Go to page, TOC, Bookmarks, and Search open above the preview. Cancelling them reveals the exact preview page and opening-position marker you left; selecting a destination closes the preview and performs the native navigation jump. The preview also closes when you tap the screen’s top-right close button, select the rendered page, or open KOReader’s settings panel. Empty-area taps and downward swipes leave it open.
- After a navigation jump, use a compact return footer: Back on the left, Forward in the center when available, and Stay here on the right. Bold, underlined “← Page …” and “Page … →” labels identify the destinations, using the same font size, row height, and side padding as the Page Preview return row. The bold, underlined Stay here action dismisses the footer while preserving KOReader's location history; the next history-producing jump opens it again. Tapping outside the footer also accepts Stay here and lets that same tap reach the reader’s normal controls. Other gestures outside the footer remain available. Menus and dialogs temporarily hide it.

Plain UI is meant to get you back to reading quickly so the feature set is deliberately small.

## Installation

Copy `plainui.koplugin` into the `plugins` folder in your KOReader installation.

Plain UI depends on KOReader's CoverBrowser plugin. Make sure CoverBrowser is installed and enabled.

KOReader's Battery statistics plugin is optional. If it is enabled, long-pressing the battery icon opens the battery statistics screen.

## Accessibility

Cover badge text uses a default font size of `13`. If the badge text is too small to read comfortably, add `plainui_badge_font_size` to KOReader's `settings.reader.lua`:

```lua
return {
    ["plainui_badge_font_size"] = 15,
}
```

Restart KOReader after changing the setting.

The Plain UI reader interface is enabled by default. To keep the library interface but use KOReader's standard reading menu without the return footer, add `plainui_reader_enabled` to `settings.reader.lua`:

```lua
return {
    ["plainui_reader_enabled"] = false,
}
```

Restart KOReader after changing the setting.

## Credits

Please visit [plainui.koplugin](https://github.com/quanganhdo/plainui.koplugin) for the latest updates.

Plain UI takes inspiration from [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) and [Project: Title](https://github.com/joshuacant/ProjectTitle).

The reader toolbar takes inspiration from the reading menu in Kobo Nickel. Action icons are adapted from [Tabler Icons v3.46.0](https://github.com/tabler/tabler-icons), copyright (c) 2020-2026 Paweł Kuna, under the MIT License included with the icons.

The metadata browser includes code adapted from [medinauta's BrowseByMetadata user patch](https://github.com/medinauta/Koreader-Patches/blob/main/2-BrowseByMetadata.lua), which was inspired by [poire-z's BrowseByMetadata proof of concept](https://github.com/koreader/koreader/issues/8472).

For related user patches by me, see [koreader-user-patches](https://github.com/quanganhdo/koreader-user-patches).

## License

MIT. See `LICENSE`.
