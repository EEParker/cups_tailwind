#!/usr/bin/env bash
# Push cups_tailwind to a remote CUPS host over SSH.
# This is a dev-machine convenience — for end users we recommend the on-host
# install.sh from a release tarball.
#
# Usage:   bash scripts/deploy-remote.sh user@host
# Example: bash scripts/deploy-remote.sh root@192.168.1.90

set -euo pipefail

TARGET=${1:?usage: deploy-remote.sh user@host}
HERE=$(cd "$(dirname "$0")/.." && pwd)
STAGE="/tmp/cups_tailwind-deploy-$$"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx  %s\033[0m\n' "$*" >&2; exit 1; }
trap 'ssh "$TARGET" "rm -rf $STAGE" 2>/dev/null || true' EXIT

# Build CSS if stale
if [ ! -f "$HERE/doc-root/cups.css" ] \
   || [ "$HERE/src/input.css" -nt "$HERE/doc-root/cups.css" ]; then
  say "Building Tailwind CSS"
  if   command -v bunx >/dev/null; then (cd "$HERE" && bunx @tailwindcss/cli -i src/input.css -o doc-root/cups.css --minify); \
  elif command -v npx  >/dev/null; then (cd "$HERE" && npx  @tailwindcss/cli -i src/input.css -o doc-root/cups.css --minify); \
  else die "Need bun or npm to build CSS. Install one or run 'npm run build' first."; fi
fi

# Build editor bundle if stale
if [ ! -f "$HERE/doc-root/cupsdconf-editor.js" ] \
   || [ "$HERE/src/cupsdconf-editor.js" -nt "$HERE/doc-root/cupsdconf-editor.js" ]; then
  say "Building cupsdconf-editor bundle"
  command -v bun >/dev/null || die "Need bun to bundle the editor JS."
  (cd "$HERE" && bun build src/cupsdconf-editor.js --outfile doc-root/cupsdconf-editor.js --minify --format=iife --target=browser)
fi

say "Checking SSH to $TARGET"
ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET" 'true' \
  || die "SSH failed. Set up key auth first."

say "Staging artifacts on $TARGET:$STAGE"
ssh "$TARGET" "mkdir -p $STAGE/templates $STAGE/doc-root"
rsync -aH --delete "$HERE/templates/" "$TARGET:$STAGE/templates/"
rsync -aH --delete --exclude='node_modules' "$HERE/doc-root/" "$TARGET:$STAGE/doc-root/"
scp "$HERE/install.sh"   "$TARGET:$STAGE/install.sh"   >/dev/null
scp "$HERE/uninstall.sh" "$TARGET:$STAGE/uninstall.sh" >/dev/null

say "Running install.sh on $TARGET"
ssh "$TARGET" "bash $STAGE/install.sh"
