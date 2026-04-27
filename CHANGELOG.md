# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-27

First public release.

### Added

- **Templates** — all 70 CUPS web UI `.tmpl` files re-authored with Tailwind
  v4 utility classes. `<header>` / `<trailer>` chrome with sticky topnav and
  brand mark; main pages (admin, jobs, classes, printers, single-printer,
  single-class) with empty-state cards and status pills; form pages
  (add/modify printer + class, choose-device/make/model/serial/uri, RSS
  subscription, edit cupsd.conf, samba export, set printer options, users);
  small status alerts for every action (printer-added, job-cancel,
  test-page, etc.); help index + printable.
- **Theme system** — Tailwind v4 `@theme` design tokens (light + dark via
  `prefers-color-scheme`). DietPi chartreuse default; gradient card-hover
  border; component classes for cards, buttons, pills, alerts, table,
  nav-link.
- **Theme picker** at `/themes.html`. Seven color presets (DietPi, Ocean,
  Sunset, Grape, Teal, Rose, Monochrome) and three card-hover border styles
  (gradient / solid / minimal). Preferences saved to `localStorage`,
  applied on every page via `theme-switcher.js`.
- **`cupsd.conf` editor** — CodeMirror 6 with a custom simple-mode parser
  for cupsd/Apache-style block syntax (`<Location>`, `<Limit>`, directives,
  `@LOCAL`/`@SYSTEM` groups, paths, comments). Light + dark themes,
  bracket matching, find/replace, undo/redo, line numbers, active-line
  highlight. Bundled as IIFE so it works regardless of CUPS' MIME mapping.
- **Touch-friendly** — 44 px button / input targets; 16 px form inputs to
  prevent iOS zoom on focus; horizontal-scrolling top nav at narrow widths;
  responsive table column hiding (sm/md/lg breakpoints).
- **Action-colored focus rings** — primary buttons get a green ring,
  cancel/danger buttons a red ring, ghost buttons a neutral ring; uses
  `:focus-visible` so the ring only appears on keyboard focus, not click.
- **Reversible install** — `install.sh` runs on the CUPS host, backs up
  upstream `/usr/share/cups/{templates,doc-root}` once to
  `.cups_tailwind_backup/`, stages the theme to `/srv/cups-tailwind/`,
  installs an APT post-invoke hook so the theme survives `cups` package
  upgrades, and applies the theme.
- **`uninstall.sh`** — removes the apt hook, the apply helper, the cache,
  and rsyncs the original templates back from the backup.
- **`scripts/deploy-remote.sh`** — dev-machine convenience that builds
  CSS + JS if stale, scps artifacts to a host over SSH, and runs
  `install.sh` there.
- **CI** — `.github/workflows/release.yml` builds tarball artifacts on
  every `v*` tag push and attaches them to the GitHub Release.

### Notes

- Bundle sizes: `doc-root/cups.css` ≈ 21 KB; `doc-root/cupsdconf-editor.js`
  ≈ 332 KB (loaded only on the cupsd.conf editor page).
- Tested on DietPi (Bookworm) on a Raspberry Pi Zero 2 W, against CUPS
  upstream as of 2026-04.

## Inspiration

Project structure and the "drop-in template replacement" approach come from
[Joakim Ewenson's cups_bootstrapped](https://github.com/JoakimEwenson/cups_bootstrapped).
Templates here were re-authored from scratch, not ported.

[Unreleased]: https://github.com/OWNER/cups_tailwind/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OWNER/cups_tailwind/releases/tag/v0.1.0
