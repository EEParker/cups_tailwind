import { EditorState } from "@codemirror/state";
import {
  EditorView, keymap, lineNumbers, highlightActiveLine,
  drawSelection, highlightActiveLineGutter,
} from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { searchKeymap, highlightSelectionMatches } from "@codemirror/search";
import {
  StreamLanguage, syntaxHighlighting, defaultHighlightStyle, bracketMatching,
} from "@codemirror/language";
import { simpleMode } from "@codemirror/legacy-modes/mode/simple-mode";
import { oneDark } from "@codemirror/theme-one-dark";

// Custom mode for cupsd.conf — block-style directives like Apache.
const cupsdConfMode = simpleMode({
  start: [
    { regex: /#.*/, token: "comment" },
    { regex: /"(?:[^"\\]|\\.)*"/, token: "string" },
    // Block tags: <Location ...> </Location> <Limit ...>
    { regex: /<\/?[A-Za-z][\w-]*/, token: "tag", next: "intag" },
    // Special @groups
    { regex: /@(?:LOCAL|SYSTEM|OWNER|[A-Z][A-Z0-9_]*)\b/, token: "variableName.special" },
    // Common boolean / enum values
    { regex: /\b(?:On|Off|Yes|No|None|Required|Default|Basic|Negotiate|allow|deny|all)\b/i, token: "atom" },
    // Well-known directives
    {
      regex: /\b(?:Listen|Port|ServerAlias|ServerName|ServerAdmin|ServerTokens|LogLevel|LogFormat|PageLogFormat|MaxLogSize|AccessLog|ErrorLog|PageLog|Browsing|BrowseLocalProtocols|BrowseRemoteProtocols|DefaultAuthType|DefaultEncryption|WebInterface|HostNameLookups|KeepAlive|KeepAliveTimeout|MaxClients|MaxClientsPerHost|MaxRequestSize|Timeout|SystemGroup|User|Group|Order|Allow|Deny|AuthType|Require|Limit|LimitExcept|Location|Policy|Encryption|JobPrivateAccess|JobPrivateValues|SubscriptionPrivateAccess|SubscriptionPrivateValues|FileDevice|PreserveJobHistory|PreserveJobFiles|MaxJobs|MaxJobsPerPrinter|MaxJobsPerUser|JobRetryInterval|JobRetryLimit|FilterLimit|FilterNice)\b/,
      token: "keyword",
    },
    // Paths
    { regex: /\/[\w./-]*/, token: "string.special" },
    // Numbers
    { regex: /\b\d+(?:\.\d+)?\b/, token: "number" },
    // Identifiers
    { regex: /[A-Za-z][\w-]*/, token: "variableName" },
  ],
  intag: [
    { regex: />/, token: "tag", next: "start" },
    { regex: /\/\w[\w/-]*/, token: "string.special" },
    { regex: /[A-Za-z][\w-]*/, token: "attributeName" },
    { regex: /\s+/, token: null },
    { regex: /./, token: null },
  ],
  languageData: { commentTokens: { line: "#" } },
});

const lightTheme = EditorView.theme(
  {
    "&": {
      fontSize: "13px",
      backgroundColor: "var(--color-surface)",
      color: "var(--color-fg)",
      borderRadius: "0.5rem",
      border: "1px solid var(--color-border)",
      height: "30rem",
    },
    ".cm-content": {
      fontFamily: "var(--font-mono, ui-monospace, monospace)",
      caretColor: "var(--color-accent)",
      padding: "0.75rem 0",
    },
    ".cm-cursor, .cm-dropCursor": { borderLeftColor: "var(--color-accent)" },
    ".cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection": {
      backgroundColor: "color-mix(in oklch, var(--color-accent) 25%, transparent)",
    },
    "&.cm-focused": {
      outline: "none",
      borderColor: "var(--color-accent)",
      boxShadow: "0 0 0 3px color-mix(in oklch, var(--color-accent) 25%, transparent)",
    },
    ".cm-gutters": {
      backgroundColor: "var(--color-surface-2)",
      color: "var(--color-fg-subtle)",
      border: "0",
      borderRight: "1px solid var(--color-border)",
      borderTopLeftRadius: "0.5rem",
      borderBottomLeftRadius: "0.5rem",
    },
    ".cm-activeLine": { backgroundColor: "color-mix(in oklch, var(--color-accent) 6%, transparent)" },
    ".cm-activeLineGutter": {
      backgroundColor: "color-mix(in oklch, var(--color-accent) 8%, transparent)",
      color: "var(--color-fg)",
    },
    ".cm-line": { padding: "0 1rem" },
    ".cm-matchingBracket, .cm-nonmatchingBracket": {
      backgroundColor: "color-mix(in oklch, var(--color-accent) 18%, transparent)",
    },
    ".cm-searchMatch": {
      backgroundColor: "color-mix(in oklch, var(--color-warning) 25%, transparent)",
      outline: "1px solid var(--color-warning)",
    },
    ".cm-panels": {
      backgroundColor: "var(--color-surface-2)",
      color: "var(--color-fg)",
      border: 0,
      borderRadius: "0.5rem",
    },
    ".cm-panel input": {
      background: "var(--color-surface)",
      color: "var(--color-fg)",
      border: "1px solid var(--color-border)",
      borderRadius: "0.375rem",
      padding: "0.25rem 0.5rem",
    },
  },
  { dark: false },
);

const prefersDark = matchMedia("(prefers-color-scheme: dark)").matches;

function init() {
  const textarea = document.querySelector('textarea[name="CUPSDCONF"]');
  if (!textarea) return;

  const wrap = document.createElement("div");
  wrap.className = "rounded-lg overflow-hidden";
  textarea.parentNode.insertBefore(wrap, textarea);
  textarea.style.display = "none";

  const view = new EditorView({
    parent: wrap,
    state: EditorState.create({
      doc: textarea.value,
      extensions: [
        lineNumbers(),
        highlightActiveLine(),
        highlightActiveLineGutter(),
        history(),
        drawSelection(),
        bracketMatching(),
        highlightSelectionMatches(),
        StreamLanguage.define(cupsdConfMode),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap, indentWithTab]),
        EditorView.lineWrapping,
        prefersDark ? oneDark : lightTheme,
      ],
    }),
  });

  // Sync editor content back to the hidden textarea on form submit
  const form = textarea.form;
  if (form) {
    form.addEventListener("submit", () => {
      textarea.value = view.state.doc.toString();
    });
  }

  // Expose for the "Use default" button which sets textarea.value directly
  window.__cupsdEditor = {
    setValue(v) {
      view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: v } });
    },
  };
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
