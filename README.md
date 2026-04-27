<p align="center">
  <img src="cups_social.png" alt="cups_tailwind" width="640">
</p>

<h1 align="center">cups_tailwind</h1>

<p align="center">
  Modernized CUPS web UI. Tailwind v4, dark-mode aware, themeable, touch-friendly.<br>
  Drop-in replacement for <code>/usr/share/cups/templates/</code> and
  <code>/usr/share/cups/doc-root/</code> on a host running CUPS.
</p>

---

## Features

- 70 CUPS template files re-authored using Tailwind v4 utility classes
- Light + dark mode via `prefers-color-scheme` (no JS toggle needed)
- 7 color presets + 3 hover-border styles via `/themes.html` (saved per-browser)
- 44 px touch targets on buttons / inputs, mobile-responsive tables
- Syntax-highlighted `cupsd.conf` editor (CodeMirror 6, custom mode)
- Reversible install — `uninstall.sh` restores the original upstream files

## Install

### Quick (release tarball, recommended)

```bash
# On the CUPS host:
curl -sSL https://github.com/<owner>/cups_tailwind/releases/latest/download/cups_tailwind.tar.gz | tar -xz
cd cups_tailwind
sudo bash install.sh
```

### Manual (clone + build)

```bash
git clone https://github.com/<owner>/cups_tailwind.git
cd cups_tailwind
bun install            # or: npm install
bun run build          # compiles doc-root/cups.css
sudo bash install.sh
```

### What `install.sh` does (every step is undoable)

1. Backs up the upstream `/usr/share/cups/{templates,doc-root}` once to
   `.cups_tailwind_backup/`.
2. Stages the theme to `/srv/cups-tailwind/` (the apply cache).
3. Installs `/usr/local/sbin/cups-tailwind-apply` (the reapply helper).
4. Installs `/etc/apt/apt.conf.d/99-cups-tailwind` so the theme survives
   `apt upgrade` of the `cups` package.
5. Applies the theme to `/usr/share/cups`.
6. Restarts cups.

## Uninstall

```bash
sudo bash uninstall.sh
```

Removes the apt hook, the apply helper, the `/srv/cups-tailwind` cache, and
restores the original templates from `.cups_tailwind_backup/`. Then restarts
cups. If the backup is missing, run `apt install --reinstall cups` to recover
the upstream files.

## Develop

```bash
bun install
bun run dev            # Tailwind watch mode, rebuilds doc-root/cups.css on save
```

To push your local changes to a host over SSH (skips building a tarball):

```bash
bash scripts/deploy-remote.sh root@192.168.1.90
```

## Releases (CI/CD)

`.github/workflows/release.yml` runs on every `v*` tag push:

1. `bun install`
2. Build `doc-root/cups.css` (Tailwind) and `doc-root/cupsdconf-editor.js` (bun bundle)
3. Stage `templates/`, `doc-root/`, `install.sh`, `uninstall.sh`, `README.md`,
   `LICENSE` into `dist/cups_tailwind/`
4. Tarball as `cups_tailwind-<version>.tar.gz`
5. Attach to a GitHub Release for the tag

To cut a release locally:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Credits

- **CUPS** — the print system this UI talks to. CUPS is a trademark of
  [Apple Inc.](https://www.apple.com/); source at
  [OpenPrinting/cups](https://github.com/OpenPrinting/cups), licensed under
  Apache-2.0.
- **Inspiration** — [Joakim Ewenson's cups_bootstrapped](https://github.com/JoakimEwenson/cups_bootstrapped),
  the Bootstrap-based CUPS theme that proved the pattern of replacing the
  default web UI templates wholesale. cups_tailwind is a ground-up rewrite
  using Tailwind v4 and modern component patterns — templates were
  re-authored, not ported — but the install approach and overall structure
  follow the trail Joakim blazed.

## License

[Apache-2.0](LICENSE), matching CUPS itself.
