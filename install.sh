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
#   4. On apt-based systems: installs /etc/apt/apt.conf.d/99-cups-tailwind so the
#      theme survives `apt upgrade` of the cups package. On other distros this
#      step is skipped — re-run install.sh manually after future cups upgrades.
#   5. Applies the theme from cache to /usr/share/cups
#   6. Restarts cups
#
# Tested on Debian / Ubuntu / Raspberry Pi OS / DietPi. Works on any systemd
# Linux with bash + cp; rsync is preferred but optional.
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

# Mirror $1/ → $2/ with delete semantics. Uses rsync when available, else cp.
sync_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -aH --delete "$src/" "$dst/"
  else
    # Wipe destination contents (keep the directory itself, drop dotfiles too)
    find "$dst" -mindepth 1 -maxdepth 100 -delete 2>/dev/null || true
    cp -a "$src/." "$dst/"
  fi
}

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash install.sh"
[ -d "$HERE/templates" ] && [ -d "$HERE/doc-root" ] \
  || die "Missing templates/ or doc-root/ next to install.sh — extract the release tarball first."
command -v cp >/dev/null || die "Need cp."
command -v rsync >/dev/null 2>&1 || warn "rsync not found — falling back to cp (slower, no incremental sync)."

# Detect apt-based system for the post-invoke hook
HAS_APT=0
if command -v apt-get >/dev/null 2>&1 && [ -d /etc/apt/apt.conf.d ]; then
  HAS_APT=1
fi

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
sync_dir "$HERE/templates" "$CACHE/templates"
sync_dir "$HERE/doc-root"  "$CACHE/doc-root"

# 3. Install reapply helper (also rsync-or-cp aware)
say "Installing /usr/local/sbin/cups-tailwind-apply"
cat > /usr/local/sbin/cups-tailwind-apply <<'APPLY'
#!/usr/bin/env bash
# Reapply cups_tailwind from /srv/cups-tailwind/ to /usr/share/cups/
# Run automatically by APT after cups package upgrades on Debian-family
# hosts; on other distros, run manually after `dnf upgrade cups`,
# `pacman -S cups`, etc.
set -e
SRC=/srv/cups-tailwind
DST=/usr/share/cups
if [ ! -d "$SRC/templates" ] || [ ! -d "$SRC/doc-root" ]; then
  echo "cups-tailwind: cache missing at $SRC, skipping" >&2
  exit 0
fi
sync_dir() {
  local s="$1" d="$2"
  mkdir -p "$d"
  if command -v rsync >/dev/null 2>&1; then
    rsync -aH --delete "$s/" "$d/"
  else
    find "$d" -mindepth 1 -maxdepth 100 -delete 2>/dev/null || true
    cp -a "$s/." "$d/"
  fi
}
sync_dir "$SRC/templates" "$DST/templates"
sync_dir "$SRC/doc-root"  "$DST/doc-root"
echo "cups-tailwind: applied $(date -Is)"
APPLY
chmod 0755 /usr/local/sbin/cups-tailwind-apply

# 4. APT post-invoke hook (only on apt-based systems)
if [ "$HAS_APT" -eq 1 ]; then
  say "Installing /etc/apt/apt.conf.d/99-cups-tailwind"
  cat > /etc/apt/apt.conf.d/99-cups-tailwind <<'HOOK'
// Reapply cups_tailwind theme after any cups package upgrade.
DPkg::Post-Invoke {
  "if dpkg-query -W -f='${Status}' cups 2>/dev/null | grep -q 'install ok installed'; then /usr/local/sbin/cups-tailwind-apply >>/var/log/cups-tailwind.log 2>&1 || true; fi";
};
HOOK
else
  warn "No apt detected — skipping post-invoke hook."
  warn "  After future cups package upgrades on this system, re-run:"
  warn "    sudo bash install.sh   # or: sudo /usr/local/sbin/cups-tailwind-apply"
fi

# 5. Apply now
say "Applying cache → $DST"
/usr/local/sbin/cups-tailwind-apply

# 6. Restart cups
say "Restarting cups"
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart cups
  systemctl is-active --quiet cups || die "cups failed to start. Check: journalctl -u cups -n 50"
else
  warn "systemctl not found — restart cups manually for changes to take effect."
fi

if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ':631 '; then
  say "Done. Open http://$(hostname -I 2>/dev/null | awk '{print $1}'):631/"
else
  say "Done. cups should be listening on :631."
fi
