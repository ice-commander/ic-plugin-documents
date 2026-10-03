#!/bin/bash
# Fetches what this plugin carries but did not write — PDFium, prebuilt by https://github.com/bblanchon/pdfium-binaries —
# into 3rdparty/out/<system>/pdfium, with THIRD-PARTY-<system>.txt. Run by hand, only when RELEASE changes:
# build-release.sh takes out/ as it is, so the files keep their md5 and the updater does not fetch them again.
#
#   bash 3rdparty/build.sh [macos] [linux] [windows]     none named: all three
#
# RELEASE matches the PDFium API that pdfium-render binds (its pdfium_latest feature). Each archive is checked against
# the sha256 GitHub publishes for it and kept in 3rdparty/cache.
set -e
cd "$(dirname "$0")"
RELEASE="chromium/7881"
CACHE="$PWD/cache/${RELEASE#chromium/}"
platforms="${*:-macos linux windows}"

for platform in $platforms; do
    case "$platform" in
        macos)
            archive=pdfium-mac-arm64.tgz inside=lib/libpdfium.dylib
            sha256=52e94ca5aa8847934330daf3f8150c190682c5ca93831468794f8b90d4392e40
            ;;
        linux)
            archive=pdfium-linux-x64.tgz inside=lib/libpdfium.so
            sha256=1470e21b8b4a3b4ad7f85684e2da11d94f3b69a86d81dee11b9b6709d927ac1d
            ;;
        windows)
            archive=pdfium-win-x64.tgz inside=bin/pdfium.dll
            sha256=73cc0de638ac2095e7445bf56a38200a5b7c7ca0e9f4ba144598f2457377ac08
            ;;
        *)
            echo "unknown system $platform: macos, linux or windows" >&2
            exit 1
            ;;
    esac
    echo "=== $platform ==="
    held="$CACHE/$archive"
    if [ ! -f "$held" ]; then
        mkdir -p "$CACHE"
        curl -fsSL -o "$held.part" \
            "https://github.com/bblanchon/pdfium-binaries/releases/download/${RELEASE/\//%2F}/$archive"
        mv "$held.part" "$held"
    fi
    if [ "$(shasum -a 256 "$held" | awk '{print $1}')" != "$sha256" ]; then
        rm -f "$held"
        echo "$archive is not the one published for $RELEASE: its sha256 differs" >&2
        exit 1
    fi
    unpacked="$CACHE/${archive%.tgz}"
    rm -rf "$unpacked"
    mkdir -p "$unpacked"
    tar -xzf "$held" -C "$unpacked"

    OUT="$PWD/out/$platform/pdfium"
    name=$(basename "$inside")
    rm -rf "$OUT"
    mkdir -p "$OUT"
    cp "$unpacked/$inside" "$OUT/$name"
    if [ "$platform" = macos ] && ! codesign -v "$OUT/$name" 2>/dev/null; then
        codesign --force --sign - "$OUT/$name"
    fi
    {
        cat licenses/NOTICE.txt
        printf '  %-24s pdfium-binaries %s (%s)\n' "$name" "$RELEASE" "$(tr '\n' ' ' < "$unpacked/VERSION" | sed 's/ *$//')"
        printf '\n\n===== pdfium.txt =====\n\n'
        cat "$unpacked/licenses/pdfium.txt"
        for text in "$unpacked"/licenses/*; do
            [ "$(basename "$text")" = pdfium.txt ] && continue
            printf '\n\n===== %s =====\n\n' "$(basename "$text")"
            cat "$text"
        done
        printf '\n\n===== pdfium-binaries build scripts: LICENSE =====\n\n'
        cat "$unpacked/LICENSE"
    } > "$OUT/THIRD-PARTY-$platform.txt"
    echo "  3rdparty/out/$platform/pdfium: $name, $(du -h "$OUT/$name" | cut -f1)"
done
