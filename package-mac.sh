#!/bin/sh
# Build a drag-to-install disk image. Only notarized images use the public filename.
set -eu
umask 077
mode=${1:?expected test or release}
source_app=${2:?expected an app bundle}
test -d "$source_app/Contents"
mkdir -p dist
stage=$(mktemp -d "$PWD/dist/.dmg-XXXXXX")
keychain="$stage/signing.keychain-db"
cleanup() {
  if [ -f "$keychain" ]; then security delete-keychain "$keychain" || :; fi
  rm -r "$stage"
}
trap 'result=$?; cleanup; exit "$result"' EXIT
mkdir "$stage/image"
app="$stage/image/Electerm Terminal.app"
ditto "$source_app" "$app"
ln -s /Applications "$stage/image/Applications"

notarize() {
  xcrun notarytool submit "$1" --key "$stage/AuthKey.p8" --key-id "$APPLE_KEY_ID" \
    --issuer "$APPLE_ISSUER_ID" --wait --output-format plist > "$stage/result.plist"
  if [ "$(plutil -extract status raw "$stage/result.plist")" != Accepted ]; then
    plutil -p "$stage/result.plist" >&2
    exit 1
  fi
  xcrun stapler staple "$2"
  xcrun stapler validate "$2"
}
case "$mode" in
  release)
    if [ -z "${DEVELOPER_ID_P12:-}" ] || [ -z "${P12_PASSWORD:-}" ] || [ -z "${APPLE_KEY_P8:-}" ] || \
       [ -z "${APPLE_KEY_ID:-}" ] || [ -z "${APPLE_ISSUER_ID:-}" ]; then
      echo "Release requires all five Apple signing/notary secrets listed in README.md." >&2
      exit 1
    fi
    printf %s "$DEVELOPER_ID_P12" | /usr/bin/base64 -D > "$stage/cert.p12"
    printf %s "$APPLE_KEY_P8" | /usr/bin/base64 -D > "$stage/AuthKey.p8"
    pass=$(openssl rand -hex 32)
    security create-keychain -p "$pass" "$keychain"
    security unlock-keychain -p "$pass" "$keychain"
    security import "$stage/cert.p12" -k "$keychain" -P "$P12_PASSWORD" -T /usr/bin/codesign
    unset DEVELOPER_ID_P12 P12_PASSWORD APPLE_KEY_P8
    security set-key-partition-list -S apple-tool:,apple: -s -k "$pass" "$keychain" >/dev/null
    identity=$(security find-identity -v -p codesigning "$keychain" | awk '/"Developer ID Application:/ {print $2}')
    if ! printf '%s\n' "$identity" | grep -Eq '^[A-F0-9a-f]{40}$' || [ "${#identity}" -ne 40 ]; then
      echo "Expected one valid Developer ID Application identity" >&2; exit 1
    fi
    codesign --force --keychain "$keychain" --sign "$identity" --timestamp --options runtime "$app/Contents/MacOS/ElectermAskpass"
    codesign --force --keychain "$keychain" --sign "$identity" --timestamp --options runtime "$app"
    codesign --verify --strict "$app"
    ditto -c -k --keepParent "$app" "$stage/notary.zip"
    notarize "$stage/notary.zip" "$app"
    spctl --assess --type execute "$app"
    name=Electerm-Terminal-mac-arm64.dmg
    ;;
  test)
    codesign --verify --strict "$app"
    name=Electerm-Terminal-mac-arm64-TEST.dmg
    ;;
  *) echo "Expected test or release" >&2; exit 2 ;;
esac
"$app/Contents/MacOS/ElectermMac" --verify-terminal
# The installation volume must be readable by users other than the build account.
chmod 755 "$stage/image"
hdiutil create -quiet -fs HFS+ -volname "Electerm Terminal" -srcfolder "$stage/image" -format UDZO "$stage/$name"
if [ "$mode" = release ]; then
  codesign --keychain "$keychain" --sign "$identity" --timestamp "$stage/$name"
  notarize "$stage/$name" "$stage/$name"
  spctl --assess --type open --context context:primary-signature "$stage/$name"
fi
hdiutil verify "$stage/$name" >/dev/null
chmod 644 "$stage/$name"
mv "$stage/$name" "dist/$name"
echo "dist/$name"
