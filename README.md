# Plain UI

Plain UI is a minimal library and reading interface for KOReader, with quick access to books and common reading controls.

See the [user guide](https://code.anh.do/plainui.koplugin/) for the full interface and everyday controls. An offline copy is included at `docs/index.html` in the release ZIP.

## Features

- Browse Books, Series, Authors, and Tags in cover grids or detailed lists, with filters and sorting.
- Swipe down while reading for typography, recent books, reading stats, and other tools.
- Use three typography profiles with adjustments remembered for each book.
- Swipe up from the bottom edge to preview pages, navigate chapters, and access bookmarks, the table of contents, and search.

The reader interface supports reflowable books and fixed-page documents such as PDFs. Typography profiles apply to reflowable books. KOReader's native menus remain available through the edge chevrons.

## Quick controls

| Where | Control |
| --- | --- |
| Library tabs | Tap the selected tab again for reading-status filters and sorting. Books also offers **Exclude folders**; **Last read** uses reading history, with unread books last. |
| Metadata results | Tap the heading above the results to add another Authors, Series, or Tags filter and narrow the selection. |
| Lighting | Tap the lighting icon for brightness controls. |
| Wi-Fi and battery | Tap Wi-Fi to turn it on/off or choose a network. Tap the battery icon for its percentage and **View battery stats** when KOReader's Battery statistics plugin is enabled. |
| Recent books | Tap the history icon beside File Manager in the reader toolbar to switch books. **View history** opens the full history list. |
| Typography profiles | Tap **Font** in the reader toolbar to adjust typography. An asterisk marks adjustments saved for the current book. |
| Reading stats | Tap a time value in the Reading stats popup to switch between decimal hours and hours/minutes, such as `1.5 hours` and `1h30m`. |
| Navigation preview | Drag the slider or swipe the preview to browse without changing your reading position. Tap the center page to jump there. The slider's dot and **Return to…** label restore the preview to the page where you opened it. |
| Navigation shortcuts | Tap the chapter name for **Go to page**. The bookmark icon inside the preview adds or removes a bookmark on that page without leaving your reading position. |
| After a navigation jump | Use the footer's Back/Forward page links to retrace jumps. **Stay here**, or a tap outside the footer, dismisses it while preserving navigation history. |
| More menu | The reader toolbar's ellipsis opens book info, cover, dictionary, and touchscreen controls. Progress and reading-statistics sync actions appear when their KOReader plugins are configured. |

Typography changes are saved automatically for the current book. **Reset** restores the selected profile's saved settings. **Save profile** updates the preset for other books using it that haven't been customized; customized books keep their own adjustments. Saving **Everyday** also updates KOReader's typography defaults.

## Installation

1. Download `plainui.koplugin.zip` from [Releases](https://github.com/quanganhdo/plainui.koplugin/releases) and extract the `plainui.koplugin` folder into KOReader's `plugins` folder. When upgrading, replace the existing plugin folder.
2. Disable other library or reader UI replacements. See [Compatibility](https://code.anh.do/plainui.koplugin/#compatibility) for tested versions and limitations.
3. Make sure both **Plain UI** and KOReader's built-in **Cover browser** plugins are enabled, then restart KOReader.

Optional KOReader built-in plugins:

- **Reading statistics** for reading stats.
- **Battery statistics** for battery history.
- **Progress sync** for syncing your reading position; set up a KOReader sync account through its **Register / Login** menu.
- **Cloud storage**, together with Reading statistics and a configured sync folder, for reading-statistics sync.

Plain UI can coexist with supported reading-stats patches and plugins; see the guide's [Compatibility](https://code.anh.do/plainui.koplugin/#compatibility) section. If Plain UI reports redundant older library patches, remove the exact files listed in the notice and restart.

Tested with KOReader `v2026.03-81-g41c9e02b5`. Other KOReader versions may work but have not been verified for this release.

## Development and releases

Use `dev` for work in progress. Run `lua tests/run.lua` for all 17 suites, then build and verify the installable ZIP:

```sh
python3 scripts/build_release.py /tmp/plainui.koplugin.zip
python3 tests/check_release.py /tmp/plainui.koplugin.zip
```

Pushes to `dev` and `main`, and pull requests, run these checks automatically. The release workflow checks out the selected release tag, runs the same checks, and uploads the verified ZIP.

The user guide publishes automatically when `docs/` changes reach `main`. Enable **Settings → Pages → Build and deployment → Source → GitHub Actions** once in the repository. WIP changes on `dev` are not published.

## Configuration

To enlarge cover badges (default size: `13`), add this entry to the existing table in KOReader's `settings.reader.lua`, then restart KOReader:

```lua
["plainui_badge_font_size"] = 15,
```

## Credits

Please visit [plainui.koplugin](https://github.com/quanganhdo/plainui.koplugin) for the latest updates.

Plain UI takes inspiration from [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) and [Project: Title](https://github.com/joshuacant/ProjectTitle).

The reader toolbar takes inspiration from the reading menu in Kobo Nickel. Action icons are adapted from [Tabler Icons v3.46.0](https://github.com/tabler/tabler-icons), copyright (c) 2020-2026 Paweł Kuna, under the MIT License included with the icons.

The metadata browser includes code adapted from [medinauta's BrowseByMetadata user patch](https://github.com/medinauta/Koreader-Patches/blob/main/2-BrowseByMetadata.lua), which was inspired by [poire-z's BrowseByMetadata proof of concept](https://github.com/koreader/koreader/issues/8472).

For related user patches by me, see [koreader-user-patches](https://github.com/quanganhdo/koreader-user-patches).

## License

MIT. See `LICENSE`.
