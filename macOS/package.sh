#!/bin/bash
# Usage: ./package.sh             unsigned dist/CodeTiles-<version>.pkg, for local testing
#        ./package.sh --release   signed, notarized and stapled, ready to publish
#
# --release needs, in the login keychain:
#   - a "Developer ID Application" and a "Developer ID Installer" certificate
#   - notarytool credentials saved as the profile in $NOTARY_PROFILE (default: codetiles-notary):
#       xcrun notarytool store-credentials codetiles-notary --apple-id <email> --team-id <TEAMID>
set -euo pipefail
cd "$(dirname "$0")"

NAME=CodeTiles
ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Info.plist)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
PKG_ID="$ID.pkg"
WORK=build/pkg
OUT="dist/$NAME-$VERSION.pkg"
NOTARY_PROFILE="${NOTARY_PROFILE:-codetiles-notary}"

RELEASE=false
case "${1:-}" in
  "") ;;
  --release) RELEASE=true ;;
  *) echo "Unknown option: $1" >&2; exit 64 ;;
esac

if $RELEASE; then
  APP_IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application[^"]*\)".*/\1/p' | head -1)
  INSTALLER_IDENTITY=$(security find-identity -v | sed -n 's/.*"\(Developer ID Installer[^"]*\)".*/\1/p' | head -1)
  [[ -n "$APP_IDENTITY" ]] || { echo "No 'Developer ID Application' certificate in the keychain." >&2; exit 1; }
  [[ -n "$INSTALLER_IDENTITY" ]] || { echo "No 'Developer ID Installer' certificate in the keychain." >&2; exit 1; }
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || { echo "No working notarytool profile '$NOTARY_PROFILE'. See the comment at the top of this script." >&2; exit 1; }
  echo "Signing with: $APP_IDENTITY"
  echo "              $INSTALLER_IDENTITY"
  SIGN_IDENTITY="$APP_IDENTITY" ./build.sh
else
  ./build.sh
fi

rm -rf "$WORK" dist
mkdir -p "$WORK/root" "$WORK/scripts" "$WORK/resources" dist
cp -R "build/$NAME.saver" "$WORK/root/"
# Extended attributes would otherwise be packed into the payload as AppleDouble "._" files.
xattr -cr "$WORK/root" 2>/dev/null || true
export COPYFILE_DISABLE=1

# Without this, Installer "relocates" the bundle into any existing copy with the same
# bundle ID it finds on disk (e.g. a build folder) instead of the Screen Savers folder.
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Delete :0:BundleIsRelocatable" "$WORK/component.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$WORK/component.plist"

cat > "$WORK/scripts/postinstall" <<'EOF'
#!/bin/bash
# Restart the screen saver host so an upgraded bundle is picked up. System Settings has to go
# too: if it stays open it keeps talking to the killed host and Options stops opening.
killall "System Settings" 2>/dev/null || true
killall legacyScreenSaver 2>/dev/null || true
exit 0
EOF
chmod +x "$WORK/scripts/postinstall"

pkgbuild --quiet \
  --root "$WORK/root" \
  --component-plist "$WORK/component.plist" \
  --identifier "$PKG_ID" \
  --version "$VERSION" \
  --install-location "/Library/Screen Savers" \
  --scripts "$WORK/scripts" \
  "$WORK/$NAME.pkg"

cat > "$WORK/resources/conclusion.txt" <<'EOF'
Code Tiles is installed.

Open System Settings > Screen Saver, choose Code Tiles under Other, and click Options... to adjust it.
EOF

cat > "$WORK/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Code Tiles</title>
    <conclusion file="conclusion.txt"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="true"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="12.0"/>
        </allowed-os-versions>
    </volume-check>
    <choices-outline>
        <line choice="$PKG_ID"/>
    </choices-outline>
    <choice id="$PKG_ID" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">$NAME.pkg</pkg-ref>
</installer-gui-script>
EOF

SIGN_ARGS=()
$RELEASE && SIGN_ARGS=(--sign "$INSTALLER_IDENTITY" --timestamp)

productbuild --quiet \
  --distribution "$WORK/distribution.xml" \
  --resources "$WORK/resources" \
  --package-path "$WORK" \
  ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
  "$OUT"

if $RELEASE; then
  echo "Notarizing (usually a few minutes)..."
  RESULT=$(xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
  STATUS=$(plutil -extract status raw -o - - <<<"$RESULT")
  if [[ "$STATUS" != "Accepted" ]]; then
    echo "Notarization failed: $STATUS" >&2
    xcrun notarytool log "$(plutil -extract id raw -o - - <<<"$RESULT")" --keychain-profile "$NOTARY_PROFILE" >&2
    exit 1
  fi
  xcrun stapler staple "$OUT"
  spctl --assess --type install -vv "$OUT"
fi

echo "Built $OUT"
