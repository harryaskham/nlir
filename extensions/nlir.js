// nlir pi extension (bd-* / pi-package): a leading `|` in your input expands the
// rest as an nlir shorthand expression via the `nlir` binary, turning terse
// stack-machine shorthand into fluent English before it reaches the model. Also
// registers `/nlir EXPR` to preview an expansion inline without sending it.
//
// Requires the `nlir` binary on PATH (install via nix/cargo). The expression is
// evaluated against your ~/.config/nlir/config.yaml (det or llm mode per your
// defaults).
//
// Examples:
//   |1+2*3            -> 7
//   |a&b&c            -> a and b and c
//   |@'the meeting is at 3'   -> (formal rewrite, llm mode)
//   /nlir 2**0.5      -> previews 1.4142135623730951

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

/** The nlir binary: `$NLIR` override, else `nlir` on PATH. */
const NLIR_BIN = process.env.NLIR || "nlir";

/** Expand an nlir shorthand expression via the `nlir` binary. */
async function expand(expr, extraArgs = []) {
  const args = ["-e", expr, "--quiet", ...extraArgs];
  const { stdout } = await run(NLIR_BIN, args, {
    timeout: 180_000,
    maxBuffer: 8 * 1024 * 1024,
  });
  return stdout.replace(/\n+$/, "");
}

function errText(err) {
  const msg = (err && (err.stderr || err.message)) || "unknown error";
  return String(msg).trim();
}

// --- nlir-mode editor tint -------------------------------------------------
// When your input begins with `|` (nlir shorthand mode), colour the editor
// border YELLOW so you can see at a glance you're in nlir mode — mirroring the
// way pi tints the border in bash mode (`!` prefix). Implemented as a custom
// editor component (there is no as-you-type input event; the editor re-renders
// per keystroke, so overriding its border colour reflects the live buffer).
const NLIR_YELLOW = "\x1b[93m"; // bright yellow
const ANSI_RESET = "\x1b[0m";
const NLIR_DIM = "\x1b[2m";
const stripAnsi = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");

// Live deterministic preview (bd-970e05): as you type an nlir expression
// (leading `|`), show the det result-so-far in a widget above the editor,
// debounced ~350ms after you stop typing, so you can iterate on a chain of
// thought without sending it. Det mode only: instant, offline, free -- no llm
// calls fire on preview. Degrades silently if `ctx.ui.setWidget` is absent.
const PREVIEW_WIDGET = "nlir-preview";
const PREVIEW_DEBOUNCE_MS = 350;
let _previewTimer = null;
let _previewLastBuffer = null;

function setPreviewWidget(ctx, lines) {
  try {
    if (ctx?.ui && typeof ctx.ui.setWidget === "function") {
      ctx.ui.setWidget(PREVIEW_WIDGET, lines);
    }
  } catch {
    /* widget API unavailable / failed -- the `|` expansion still works. */
  }
}

function clearPreview(ctx) {
  if (_previewTimer) {
    clearTimeout(_previewTimer);
    _previewTimer = null;
  }
  _previewLastBuffer = null;
  setPreviewWidget(ctx, []);
}

// Debounce a deterministic eval of `buffer` (a leading-`|` nlir line) and show
// the result-so-far above the editor. A mid-edit / non-det expression clears
// the widget rather than flickering an error.
function schedulePreview(ctx, buffer) {
  if (_previewTimer) clearTimeout(_previewTimer);
  _previewTimer = setTimeout(async () => {
    _previewTimer = null;
    const expr = buffer.replace(/^\|/, "").trim();
    if (!expr) {
      setPreviewWidget(ctx, []);
      return;
    }
    try {
      const out = await expand(expr, ["--mode", "det"]);
      const flat = out ? out.replace(/\n+/g, " ").trim() : "";
      setPreviewWidget(
        ctx,
        flat ? [`${NLIR_YELLOW}nlir \u00bb${ANSI_RESET} ${NLIR_DIM}${flat}${ANSI_RESET}`] : [],
      );
    } catch {
      // Incomplete/unparseable or non-deterministic mid-edit: no preview yet.
      setPreviewWidget(ctx, []);
    }
  }, PREVIEW_DEBOUNCE_MS);
}

/** Register the nlir-mode yellow-border editor, degrading silently if the
 *  running pi build doesn't expose CustomEditor / setEditorComponent. */
async function installNlirModeEditor(ctx) {
  try {
    if (!ctx?.ui || typeof ctx.ui.setEditorComponent !== "function") return;
    const mod = await import("@earendil-works/pi-coding-agent");
    const CustomEditor = mod?.CustomEditor;
    if (!CustomEditor) return;

    const inNlirMode = (self) => {
      try {
        return typeof self.getText === "function" && self.getText().startsWith("|");
      } catch {
        return false;
      }
    };

    class NlirModeEditor extends CustomEditor {
      // If the base editor routes all border chars through borderColor(), this
      // yellows the whole box in nlir mode.
      borderColor(text) {
        if (inNlirMode(this)) return NLIR_YELLOW + text + ANSI_RESET;
        return super.borderColor(text);
      }

      // Belt-and-suspenders: recolour the top/bottom border lines directly, so
      // the yellow shows even if the base border isn't drawn via borderColor().
      render(width) {
        const lines = super.render(width);
        try {
          let text = "";
          try {
            text = typeof this.getText === "function" ? this.getText() : "";
          } catch {
            text = "";
          }
          const nlir = text.startsWith("|");
          if (nlir && lines.length >= 2) {
            lines[0] = NLIR_YELLOW + stripAnsi(lines[0]) + ANSI_RESET;
            lines[lines.length - 1] = NLIR_YELLOW + stripAnsi(lines[lines.length - 1]) + ANSI_RESET;
          }
          // Live det preview (bd-970e05): re-render is the only per-keystroke
          // hook, so (re)schedule the debounced preview when the buffer actually
          // changes (robust to per-frame re-renders), and clear it on exit.
          if (nlir) {
            if (text !== _previewLastBuffer) {
              _previewLastBuffer = text;
              schedulePreview(ctx, text);
            }
          } else if (_previewLastBuffer !== null) {
            clearPreview(ctx);
          }
        } catch {
          /* fall back to the un-tinted lines on any render error */
        }
        return lines;
      }
    }

    ctx.ui.setEditorComponent((tui, theme, keybindings) => new NlirModeEditor(tui, theme, keybindings));
  } catch {
    /* CustomEditor unavailable or wiring failed — the `|` expansion still works. */
  }
}

export default function (pi) {
  // Yellow editor border while you're typing an nlir expression (leading `|`).
  pi.on("session_start", async (_event, ctx) => {
    await installNlirModeEditor(ctx);
  });

  // `|expr` -> expand via nlir, then continue with the English (transform), so a
  // terse nlir line becomes the fluent message the model sees.
  pi.on("input", async (event, ctx) => {
    const text = event.text ?? "";
    // Don't recurse on extension-injected messages.
    if (event.source === "extension") return { action: "continue" };
    if (!text.startsWith("|")) return { action: "continue" };
    const expr = text.slice(1).trim();
    if (!expr) return { action: "continue" };
    clearPreview(ctx); // the line is being sent; drop the live preview widget
    try {
      const out = await expand(expr);
      if (!out) return { action: "continue" };
      return { action: "transform", text: out };
    } catch (err) {
      ctx.ui.notify(`nlir: ${errText(err)}`, "error");
      return { action: "handled" };
    }
  });

  // `/nlir EXPR` -> preview the expansion inline without sending it to the model.
  pi.registerCommand("nlir", {
    description: "Expand an nlir shorthand expression (or prefix your input with `|`)",
    handler: async (args, ctx) => {
      const expr = (args ?? "").trim();
      if (!expr) {
        ctx.ui.notify("usage: /nlir EXPR   (e.g. /nlir 1+2*3, /nlir a&b&c)", "info");
        return;
      }
      try {
        const out = await expand(expr);
        ctx.ui.notify(out || "(empty result)", "info");
      } catch (err) {
        ctx.ui.notify(`nlir: ${errText(err)}`, "error");
      }
    },
  });
}
