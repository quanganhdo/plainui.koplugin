# Plain UI

Plain UI is a minimal home screen for KOReader focused on quick access to your library.

It adds a tab bar for Books, Series, and Authors, plus a compact status area for common device controls.

## Features

- Use Series and Authors tabs with Mosaic and Detailed list display modes.
- Quick access from the home screen to dark mode, frontlight, and Wi-Fi.
- Long-press the frontlight icon to toggle the frontlight.
- Long-press the Wi-Fi icon to choose a network.
- Long-press the battery icon to view battery information.

This is meant to get you to resume your reading quickly, so there are no customization options and the feature set is deliberately small.

## Installation

Copy `plainui.koplugin` into the `plugins` folder in your KOReader installation.

Plain UI depends on KOReader's CoverBrowser plugin. Make sure CoverBrowser is installed and enabled.

KOReader's Battery statistics plugin is optional. If it is enabled, long-pressing the battery icon opens the battery statistics screen.

## Credits

Plain UI takes inspiration from [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin) and [Project: Title](https://github.com/joshuacant/ProjectTitle).

The author and series browser includes code adapted from [medinauta's BrowseByMetadata user patch](https://github.com/medinauta/Koreader-Patches/blob/main/2-BrowseByMetadata.lua), which was inspired by [poire-z's BrowseByMetadata proof of concept](https://github.com/koreader/koreader/issues/8472).

For related user patches by me, see [koreader-user-patches](https://github.com/quanganhdo/koreader-user-patches).

## License

MIT. See `LICENSE`.
