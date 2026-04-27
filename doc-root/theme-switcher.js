/* cups_tailwind theme switcher
 * Applies a stored color preset by overriding CSS custom properties on :root.
 * Loaded on every page (via header.tmpl). Picker UI lives at /themes.html.
 */
(function () {
  const THEMES = {
    dietpi:   { name: "DietPi",      hue: 128, chroma: 0.22, accentL: 0.94, accentC: 0.24 },
    ocean:    { name: "Ocean",       hue: 220, chroma: 0.18, accentL: 0.70, accentC: 0.18 },
    sunset:   { name: "Sunset",      hue: 35,  chroma: 0.18, accentL: 0.78, accentC: 0.18 },
    grape:    { name: "Grape",       hue: 295, chroma: 0.16, accentL: 0.65, accentC: 0.20 },
    teal:     { name: "Teal",        hue: 195, chroma: 0.15, accentL: 0.78, accentC: 0.14 },
    rose:     { name: "Rose",        hue: 8,   chroma: 0.18, accentL: 0.70, accentC: 0.20 },
    mono:     { name: "Monochrome",  hue: 264, chroma: 0.01, accentL: 0.65, accentC: 0.005 },
  };

  const BORDERS = ["gradient", "solid", "minimal"];

  function getStored() {
    return {
      theme: localStorage.getItem("cups-theme") || "dietpi",
      border: localStorage.getItem("cups-border") || "gradient",
    };
  }

  function setStored(theme, border) {
    if (theme)  localStorage.setItem("cups-theme",  theme);
    if (border) localStorage.setItem("cups-border", border);
    apply();
  }

  function vars(theme, isDark) {
    const t = THEMES[theme] || THEMES.dietpi;
    const linkL  = isDark ? 0.85 : 0.58;
    const linkLH = isDark ? 0.92 : 0.50;
    const cardL  = isDark ? 0.22 : 0.96;
    const accentFg = t.accentL > 0.7 ? `oklch(0.18 0.02 ${t.hue})` : `oklch(0.99 0 0)`;
    return {
      "--color-accent":        `oklch(${t.accentL} ${t.accentC} ${t.hue})`,
      "--color-accent-hover":  `oklch(${Math.max(0.40, t.accentL - 0.06)} ${t.accentC + 0.01} ${t.hue})`,
      "--color-accent-fg":     accentFg,
      "--color-link":          `oklch(${linkL} ${t.chroma} ${t.hue})`,
      "--color-link-hover":    `oklch(${linkLH} ${t.chroma + 0.01} ${t.hue})`,
      "--color-card-hover":    `oklch(${cardL} 0.06 ${t.hue})`,
    };
  }

  function apply() {
    const { theme, border } = getStored();
    const isDark = matchMedia("(prefers-color-scheme: dark)").matches;
    const root = document.documentElement;
    const v = vars(theme, isDark);
    for (const k of Object.keys(v)) root.style.setProperty(k, v[k]);
    root.dataset.cupsBorder = BORDERS.includes(border) ? border : "gradient";
    root.dataset.cupsTheme  = THEMES[theme] ? theme : "dietpi";
  }

  // Apply ASAP (script is `defer`d, so DOM is parsed when this runs)
  apply();

  // Re-apply when system color scheme changes
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", apply);
  // Re-apply when another tab changes the stored theme
  window.addEventListener("storage", apply);

  // Expose for the picker page
  window.cupsTheme = { THEMES, BORDERS, getStored, setStored, apply };
})();
