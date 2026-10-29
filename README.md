# Code Tiles

A macOS screen saver of coloured tiles that fade in and out on a square grid. Some tiles carry a programming file extension (`.js`, `.py`, `.rs`, …), the rest are blank.

![Code Tiles, light background](docs/screenshot-light.png)

![Code Tiles, dark mode](docs/screenshot-dark.png)

## Features

- Tiles appear and disappear at random, each on its own timer, and tend to grow in small clusters.
- Default fade timings were measured frame by frame from reference footage (fade in 0.7 s, fade out 0.8 s).
- Labels linger slightly as a tile fades, leaving faint "ghost" text.
- Light (off-white) or dark (black) background.
- Everything is adjustable from the screen saver's Options panel.
- Universal binary for Apple Silicon and Intel Macs; animation runs on Core Animation, so CPU use stays negligible even on 5K displays.

## Requirements

- macOS 12 Monterey or later
- Xcode or the Xcode Command Line Tools (`xcode-select --install`) to build

## Build and install

```bash
git clone https://github.com/charlie-f/codetiles.git
cd codetiles/macOS
./build.sh install
```

`./build.sh` on its own builds `macOS/build/CodeTiles.saver` without installing it. `install` copies it to `~/Library/Screen Savers` and restarts the macOS screen saver host so the new build is picked up.

Then open **System Settings → Screen Saver**, choose **Code Tiles** under *Other*, and click **Options…** to adjust it.

## Options

![Options panel](docs/options.png)

| Setting | Range | Default | What it does |
| --- | --- | --- | --- |
| Tile density | 5–90% | 30% | Share of grid cells showing a tile at any moment |
| Tiles with extensions | 0–100% | 35% | Share of tiles that carry a label; the rest are blank |
| Fade in | 0.05–3 s | 0.70 s | How long a tile takes to appear |
| Fade out | 0.05–3 s | 0.80 s | How long a tile takes to disappear |
| Appearance | on / off | off | Dark mode: black background instead of off-white |
| Extensions | up to 64 | `.js .ts .py .rb .go .rs .c .cs .kt .sh` | Labels to show, separated by spaces or commas. Any text works, e.g. `.json .toml if()` |

**Restore Defaults** resets every option.

## Uninstall

```bash
rm -rf ~/Library/Screen\ Savers/CodeTiles.saver
```

## Notes

- The build is ad-hoc signed, which is enough to run it on the Mac that built it. A pre-built `.saver` downloaded by someone else will be blocked by Gatekeeper unless it is signed with a Developer ID and notarized; building from source avoids this.
- On macOS 14 and later the system keeps stopped screen saver instances running in the background. Code Tiles quits its process shortly after the screen saver stops to avoid that.

## Project layout

```
macOS/
  build.sh                 build, sign and optionally install
  Info.plist               bundle metadata
  Resources/               thumbnails shown in System Settings
  Sources/
    CodeTilesView.swift    grid, tile lifecycle and animation
    ConfigController.swift Options panel
    Settings.swift         saved preferences and defaults
    Palette.swift          tile and background colours
docs/                      README images
```

A Windows version is planned.

## License

[MIT](LICENSE)
