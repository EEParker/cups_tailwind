#!/usr/bin/env bash
# cups_tailwind on-host uninstaller.
#
# Run on the CUPS server:
#   sudo bash uninstall.sh
#
# Reverses every change install.sh made:
#   1. Removes the APT post-invoke hook
#   2. Removes the reapply helper script
#   3. Removes the staging cache at /srv/cups-tailwind
#   4. Restores /usr/share/cups/{templates,doc-root} from .cups_tailwind_backup/
#   5. Removes the backup directory
#   6. Restarts cups
#
# If the backup directory is missing (you wiped it manually), the script will
# tell you to run `apt install --reinstall cups` to get the upstream files
# back.

set -euo pipefail

DST=/usr/share/cups
CACHE=/srv/cups-tailwind
BACKUP="$DST/.cups_tailwind_backup"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31mxx  %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash uninstall.sh"

say "Removing /etc/apt/apt.conf.d/99-cups-tailwind"
rm -f /etc/apt/apt.conf.d/99-cups-tailwind

say "Removing /usr/local/sbin/cups-tailwind-apply"
rm -f /usr/local/sbin/cups-tailwind-apply

say "Removing cache $CACHE"
rm -rf "$CACHE"

if [ -d "$BACKUP/templates" ] && [ -d "$BACKUP/doc-root" ]; then
  say "Restoring upstream theme from $BACKUP"
  rsync -aH --delete "$BACKUP/templates/" "$DST/templates/"
  rsync -aH --delete "$BACKUP/doc-root/"  "$DST/doc-root/"
  rm -rf "$BACKUP"
else
  warn "No backup at $BACKUP — nothing to restore."
  warn "If $DST is left in a broken state, run:"
  warn "    apt install --reinstall cups"
fi

say "Restarting cups"
systemctl restart cups || true
systemctl is-active --quiet cups \
  && say "Done. cups is active." \
  || warn "cups did not come back up cleanly. Check: journalctl -u cups -n 50"
