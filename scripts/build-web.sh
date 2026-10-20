#!/usr/bin/env bash
# Builds Soniq's renderer in iOS mode and copies it into web/ for `cap sync ios`.
# SONIQ_DIR defaults to the desktop checkout next to this repo; CI points it at its own checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SONIQ_DIR="${SONIQ_DIR:-$ROOT/../../desktop-merged}"

if [ "${SKIP_SONIQ_BUILD:-0}" != "1" ]; then
  (cd "$SONIQ_DIR" && pnpm install --frozen-lockfile && pnpm run build:ios)
fi

test -f "$SONIQ_DIR/dist-mobile/index.html" || { echo "missing $SONIQ_DIR/dist-mobile/index.html" >&2; exit 1; }
rm -rf "$ROOT/web"
cp -R "$SONIQ_DIR/dist-mobile" "$ROOT/web"
echo "copied $(node -p "require('$SONIQ_DIR/package.json').version") renderer into web/"
