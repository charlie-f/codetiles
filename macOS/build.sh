#!/bin/bash
# Usage: ./build.sh            build build/CodeTiles.saver
#        ./build.sh install    build and install to ~/Library/Screen Savers
# Set SIGN_IDENTITY to a "Developer ID Application" identity to sign for distribution;
# otherwise the bundle is ad-hoc signed, which only runs on the Mac that built it.
set -euo pipefail
cd "$(dirname "$0")"

NAME=CodeTiles
SAVER="build/$NAME.saver"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

rm -rf build
mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"

for arch in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -module-name "$NAME" \
    -target "$arch-apple-macos12.0" \
    -emit-executable -Xlinker -bundle \
    -framework ScreenSaver -framework AppKit \
    Sources/*.swift -o "build/$NAME-$arch"
done

lipo -create "build/$NAME-arm64" "build/$NAME-x86_64" -output "$SAVER/Contents/MacOS/$NAME"
rm "build/$NAME-arm64" "build/$NAME-x86_64"
cp Info.plist "$SAVER/Contents/"
cp Resources/* "$SAVER/Contents/Resources/"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$SAVER"
else
  # Notarization requires the hardened runtime and a secure timestamp.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SAVER"
fi
echo "Built $SAVER"

if [[ "${1:-}" == "install" ]]; then
  DEST="$HOME/Library/Screen Savers"
  mkdir -p "$DEST"
  rm -rf "$DEST/$NAME.saver"
  cp -R "$SAVER" "$DEST/"
  # The screen saver host caches loaded bundles; restart it so the new build is picked up.
  killall legacyScreenSaver 2>/dev/null || true
  echo "Installed to $DEST/$NAME.saver"
fi
