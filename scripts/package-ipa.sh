#!/usr/bin/env bash
# Wraps an unsigned App.app from an xcarchive into Payload/ and zips it as an .ipa.
# Usage: package-ipa.sh <path/to/Soniq.xcarchive> <output.ipa>
set -euo pipefail

ARCHIVE="$1"
OUT="$2"
APP="$ARCHIVE/Products/Applications/App.app"

test -d "$APP" || { echo "missing $APP" >&2; exit 1; }
test -f "$APP/public/index.html" || { echo "web assets missing from App.app" >&2; exit 1; }
plutil -extract UIBackgroundModes json -o - "$APP/Info.plist" | grep -q audio || { echo "UIBackgroundModes audio missing" >&2; exit 1; }

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
# ad-hoc signature so TrollStore can install it directly; AltStore/Sideloadly re-sign anyway
codesign --force --deep --sign - "$STAGE/Payload/App.app"
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUT_ABS"
(cd "$STAGE" && zip -qry "$OUT_ABS" Payload)
rm -rf "$STAGE"
echo "wrote $OUT_ABS ($(du -h "$OUT_ABS" | cut -f1))"
