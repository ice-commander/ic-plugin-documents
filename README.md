# Documents

A document viewer plugin for Ice Commander. PDF is the only format so far.

## What it opens

`.pdf`, by extension only: the application picks a viewer by the file's
extension and does not look inside the file. The plugin registers the viewer
`pdf-view` at priority 0, so opening a `.pdf` for viewing lands here.

The window is a declarative document every frontend draws: the page, and under
it back and forward buttons (also on `Left` and `Right`, greyed out on the
first and last page) with the file's name and *page / pages*. The page keeps its
proportions, fits the window and can be zoomed by the frontend.

## A page at a time

Only the page on screen is rendered. The window's document names it —
`part:page/3` — instead of carrying it, and the host asks the plugin for those
pixels when it draws. The plugin keeps only the last page it rendered.

Turning a page answers `{"redescribe":true}`; the new document names the new
page.

Pages are rendered 1600 pixels wide, on white, as PNG.

## Where the file comes from

The plugin first asks the host for a local path (`fs_local_path`); with one,
pdfium reads the file itself. Without one, the whole file is read through
`fs_open` and kept in memory while the window is open.

The document is opened for every render and closed again rather than held:
pdfium keeps the file open, and an open window must not keep a lock on it.

## libpdfium

pdfium is bound at run time, from the first of:

1. `pdfium/` beside the plugin, where the plugin carries it;
2. beside the running executable (the application's, not the plugin's);
3. `../Libs` from there, the macOS bundle layout;
4. on Linux, `/usr/lib/ice-commander/libpdfium.so`, then `/usr/lib/libpdfium.so`;
5. the system's library search path.

The carried library is the prebuilt one of
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries),
release `chromium/7881` — the PDFium API `pdfium-render` binds — with
`THIRD-PARTY-<system>.txt` beside it: PDFium's licence and those of the code
built into it.

Without it no page can be counted, so the plugin refuses the file at open and
the application reports that the viewer could not open it.

## Not in a terminal

A console host has nothing to draw a page onto, so the plugin refuses to load
there rather than claiming `.pdf` and showing nothing.

## Known limitations

- One page at a time: no continuous scrolling, no jump to a page, no text
  search or selection, no printing.
- Pages are always rendered 1600 pixels wide, whatever the window size or zoom.
- Documents that need a password to open are refused; there is no prompt for
  one.
- The page count is held as a 16-bit number, so a document of more than 65 535
  pages is miscounted.
- The tests cover page turning and part lookup without pdfium; rendering itself
  is not tested.

## Building

```sh
bash 3rdparty/build.sh   # pdfium of all three systems into 3rdparty/out; by hand, when RELEASE changes
./build.sh               # release build into bin/, with this system's pdfium in bin/pdfium
./test.sh                # cargo test --workspace
./deploy-local.sh        # copies bin/ into the plugin folder
./build-release.sh       # all three systems into distr/, with pdfium from 3rdparty/out as it is
```

`3rdparty/build.sh` downloads the archives of the pinned release, checks each
against the sha256 GitHub publishes for it, and keeps them in
`3rdparty/cache/`. The release does not fetch again, so a new version of the
plugin ships the same pdfium files with the same md5, and the updater leaves
them alone.

`build.sh` produces `libic_pdf_view.dylib`, `libic_pdf_view.so` or
`ic_pdf_view.dll`. `ic-plugin-api` is fetched from
`github.com/ice-commander/plugin-api` (branch `main`).

`deploy-local.sh` copies into `~/Library/Application Support/ice-commander/plugins`
on macOS, `%APPDATA%\ice-commander\plugins` on Windows and
`${XDG_DATA_HOME:-~/.local/share}/ice-commander/plugins` elsewhere;
`IC_PLUGIN_DIR` overrides it. Then switch the plugin on in
**Settings → Plugins** and restart.

`version.rs` is generated from `package.json` by `node builder/gen-version.js`
(`npm run gen-version`) and is the version the plugin reports. `build.sh` does
not regenerate it.

## Licence

MIT or Apache-2.0, at your option. The carried pdfium keeps its own licence, in
`THIRD-PARTY-<system>.txt` beside it. Contributions are taken under the
[DCO](DCO); sign off with `git commit -s`.
