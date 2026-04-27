#!/usr/bin/env bash
# cups_tailwind on-host installer.
#
# Run on the CUPS server (not on your dev machine):
#   sudo bash install.sh
#
# What this does — every step is reversible by uninstall.sh:
#   1. One-time backup of /usr/share/cups/{templates,doc-root} → .cups_tailwind_backup/
#   2. Stages the theme to /srv/cups-tailwind/ (cache, kept in sync on every install)
#   3. Installs /usr/local/sbin/cups-tailwind-apply (the reapply helper)
#   4. Installs /etc/apt/apt.conf.d/99-cups-tailwind (auto-runs the helper after cups apt upgrades)
#   5. Applies the theme from cache to /usr/share/cups
#   6. Restarts cups
#
# To deploy from a dev machine over SSH instead, use scripts/deploy-remote.sh.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
DST=/usr/share/cups
CACHE=/srv/cups-tailwind
BACKUP="$DST/.cups_tailwind_backup"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31mxx  %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash install.sh"
[ -d "$HERE/templates" ] && [ -d "$HERE/doc-root" ] \
  || die "Missing templates/ or doc-root/ next to install.sh — extract the release tarball first."
command -v rsync >/dev/null || die "Need rsync. Install with: apt install rsync"

# 1. Backup originals (one-shot — never overwritten)
if [ ! -d "$BACKUP" ]; then
  say "Backing up upstream theme → $BACKUP"
  mkdir -p "$BACKUP"
  cp -a "$DST/templates" "$BACKUP/"
  cp -a "$DST/doc-root"  "$BACKUP/"
else
  say "Backup already present, leaving alone: $BACKUP"
fi

# 2. Stage to cache
say "Staging cups_tailwind → $CACHE"
mkdir -p "$CACHE/templates" "$CACHE/doc-root"
rsync -aH --delete "$HERE/templates/" "$CACHE/templates/"
rsync -aH --delete "$HERE/doc-root/"  "$CACHE/doc-root/"

# 3. Install reapply helper
say "Installing /usr/local/sbin/cups-tailwind-apply"
cat > /usr/local/sbin/cups-tailwind-apply <<'APPLY'
#!/usr/bin/env bash
# Reapply cups_tailwind from /srv/cups-tailwind/ to /usr/share/cups/
# Run automatically by APT after any cups package upgrade.
set -e
SRC=/srv/cups-tailwind
DST=/usr/share/cups
if [ ! -d "$SRC/templates" ] || [ ! -d "$SRC/doc-root" ]; then
  echo "cups-tailwind: cache missing at $SRC, skipping" >&2
  exit 0
fi
rsync -aH --delete "$SRC/templates/" "$DST/templates/"
rsync -aH --delete "$SRC/doc-root/"  "$DST/doc-root/"
echo "cups-tailwind: applied $(date -Is)"
APPLY
chmod 0755 /usr/local/sbin/cups-tailwind-apply

# 4. Install APT hook
say "Installing /etc/apt/apt.conf.d/99-cups-tailwind"
cat > /etc/apt/apt.conf.d/99-cups-tailwind <<'HOOK'
// Reapply cups_tailwind theme after any cups package upgrade.
DPkg::Post-Invoke {
  "if dpkg-query -W -f='${Status}' cups 2>/dev/null | grep -q 'install ok installed'; then /usr/local/sbin/cups-tailwind-apply >>/var/log/cups-tailwind.log 2>&1 || true; fi";
};
HOOK

# 5. Apply now
say "Applying cache → $DST"
/usr/local/sbin/cups-tailwind-apply

# 6. Restart cups
say "Restarting cups"
systemctl restart cups
systemctl is-active --quiet cups || die "cups failed to start. Check: journalctl -u cups -n 50"

if ss -ltn | grep -q ':631 '; then
  say "Done. Open http://$(hostname -I | awk '{print $1}'):631/"
else
  warn "cups is active but not listening on :631 yet — give it a few seconds."
fi
