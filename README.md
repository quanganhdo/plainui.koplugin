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
- Swipe down while reading to open a compact toolbar with typography, reading statistics, table of contents, and search actions.
- Adjust font, spacing, margins, and alignment from a compact typography panel.

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

## Credits

Please visit [plainui.koplugin](https://github.com/quanganhdo/plainui.koplugin) for the latest updates.

Plain UI takes inspiration from [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) and [Project: Title](https://github.com/joshuacant/ProjectTitle).

The reader toolbar takes inspiration from the reading menu in Kobo Nickel. Action icons are adapted from [Tabler Icons v3.46.0](https://github.com/tabler/tabler-icons), copyright (c) 2020-2026 Paweł Kuna, under the MIT License included with the icons.

The metadata browser includes code adapted from [medinauta's BrowseByMetadata user patch](https://github.com/medinauta/Koreader-Patches/blob/main/2-BrowseByMetadata.lua), which was inspired by [poire-z's BrowseByMetadata proof of concept](https://github.com/koreader/koreader/issues/8472).

For related user patches by me, see [koreader-user-patches](https://github.com/quanganhdo/koreader-user-patches).

## License

MIT. See `LICENSE`.
