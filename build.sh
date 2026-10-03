#!/bin/sh
set -e
cd "$(dirname "$0")"

case "$(uname -s)" in
    Darwin) EXT=dylib ;;
    MINGW*|MSYS*|CYGWIN*) EXT=dll ;;
    *) EXT=so ;;
esac

# A renamed crate leaves its old library in target/, where it would be collected as current.
rm -f bin/target/release/*."$EXT"

cargo build --release
mkdir -p bin
rm -f "bin/"*."$EXT"

found=0
for library in bin/target/release/*."$EXT"; do
    [ -f "$library" ] || continue
    cp "$library" bin/
    found=$((found + 1))
    printf '%s\n' "  $(basename "$library")"
done

if [ "$found" -eq 0 ]; then
    echo "no plugin libraries were produced" >&2
    exit 1
fi
# What 3rdparty/build.sh made for this system, in the folder the plugin looks in beside itself.
case "$(uname -s)" in
    Darwin) PLATFORM=macos ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
    *) PLATFORM=linux ;;
esac
rm -rf bin/pdfium
if [ -d "3rdparty/out/$PLATFORM/pdfium" ]; then
    cp -a "3rdparty/out/$PLATFORM/pdfium" bin/pdfium
    echo "  pdfium in bin/pdfium"
else
    echo "  no 3rdparty/out/$PLATFORM/pdfium — bash 3rdparty/build.sh $PLATFORM makes it; without it no PDF opens"
fi
echo "$found plugin(s) in bin/"
