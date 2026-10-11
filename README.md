# Plain UI

Plain UI is a minimal library and reading interface for KOReader, with quick access to books and common reading controls.

## Features

- Browse Books, Series, Authors, and Tags in cover grids or detailed lists, with filters and sorting.
- See reading progress and finished-book badges on covers.
- Access lighting, dark mode, and Wi-Fi from the library and reader.
- Swipe down while reading for typography, recent books, reading stats, and other tools. Sync actions appear when configured.
- Use three typography profiles with adjustments remembered for each book.
- Swipe up from the bottom edge to preview pages, navigate chapters, and access bookmarks, the table of contents, and search.
- Use Back, Forward, and Stay here after navigation jumps.

The custom reader interface supports reflowable books such as EPUB. KOReader's native menus remain available through the edge chevrons.

## Installation

Copy `plainui.koplugin` into KOReader's `plugins` folder, enable the CoverBrowser plugin, and restart KOReader.

The optional Battery statistics plugin adds a statistics screen when you long-press the battery icon.

## Configuration

Add these optional settings to the existing table in KOReader's `settings.reader.lua`, then restart KOReader.

To enlarge cover badges (default size: `13`):

```lua
["plainui_badge_font_size"] = 15,
```

To keep the library interface and use KOReader's native reader controls:

```lua
["plainui_reader_enabled"] = false,
```

## Credits

Please visit [plainui.koplugin](https://github.com/quanganhdo/plainui.koplugin) for the latest updates.

Plain UI takes inspiration from [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) and [Project: Title](https://github.com/joshuacant/ProjectTitle).

The reader toolbar takes inspiration from the reading menu in Kobo Nickel. Action icons are adapted from [Tabler Icons v3.46.0](https://github.com/tabler/tabler-icons), copyright (c) 2020-2026 Paweł Kuna, under the MIT License included with the icons.

The metadata browser includes code adapted from [medinauta's BrowseByMetadata user patch](https://github.com/medinauta/Koreader-Patches/blob/main/2-BrowseByMetadata.lua), which was inspired by [poire-z's BrowseByMetadata proof of concept](https://github.com/koreader/koreader/issues/8472).

For related user patches by me, see [koreader-user-patches](https://github.com/quanganhdo/koreader-user-patches).

## License

MIT. See `LICENSE`.
