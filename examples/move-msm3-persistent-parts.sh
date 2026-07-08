#!/usr/bin/env bash
# nlir showcase · msm3 · CROSS-PROGRAM PERSISTENT PARTS — the library that COMPOUNDS
#
# Harry's pyramid: "what you learn in one round can inform a more complex example
# next round … build up a pyramid of thought." The literal mechanism: a PART is a
# named form; persist it to a context-file LIBRARY, and it is reusable in EVERY
# LATER program — across invocations, across sessions. A part built once is yours
# forever; trains compose parts from the shared library.
#
#   nlir --context-file lib  -e "greet={('Hello, '++$0++'!')}"   # define + persist
#   nlir --context-file lib  -e "$greet%'Ada'"                   # SEPARATE run, reuse → Hello, Ada!
#   nlir --context-file lib  -e "$shout%($greet%'Ada')"          # compose persisted parts
#
# This only works because forms round-trip through context with their string
# literals intact (bd-4fb6d0): before that fix a persisted `'Hello, '` lost its
# quotes and corrupted the stored part. The det parts below run OFFLINE (CI-green,
# no model); the generative parts need LITELLM_MASTER_KEY (skipped without it).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
HAVE_KEY=0; [ -n "${LITELLM_MASTER_KEY:-}" ] && HAVE_KEY=1

# A fresh library file per run; each nlir call below is a SEPARATE process that
# shares only this file — proving the parts persist ACROSS programs, not within one.
LIB="$(mktemp -t nlir-parts-lib.XXXXXX.json)"
trap 'rm -f "$LIB"' EXIT

say()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
why()  { printf '   \033[2m(%s)\033[0m\n' "$1"; }
prog() { # MODE EXPR   — a standalone nlir program sharing the persistent library
  if [ "$1" = llm ] && [ "$HAVE_KEY" = 0 ]; then printf '  ~ SKIP (no LITELLM_MASTER_KEY)\n'; return 0; fi
  printf '  $ nlir -e %q\n  => ' "$2"
  "$NLIR" --config "$CFG" --context-file "$LIB" --mode "$1" --quiet -e "$2" 2>&1 | tail -1
}

say "ROUND 1 (det, offline) — define a PART with prose literals, persist it to the library"
why "greet embeds the literals 'Hello, ' and '!'; before bd-4fb6d0 these lost their quotes on persist and broke the part"
prog det "greet={('Hello, '++\$0++'!')}"

say "ROUND 2 (det, offline) — a SEPARATE program reuses the persisted part"
why "this nlir process only shares the library file; \$greet was defined in Round 1, not here"
prog det "\$greet%'Ada'"

say "ROUND 3 (det, offline) — grow the library: add a second part, then COMPOSE both in a train"
why "shout is added in its own program; the next program composes shout∘greet — the library compounds"
prog det "shout={(\$0++': !!!')}"
prog det "\$shout%(\$greet%'Ada')"

say "ROUND 4 (llm) — the payoff: a GENERATIVE part, persisted once, reused across programs"
why "def carries a prose instruction ('a one-line plain-English definition of: '); only persistable after bd-4fb6d0"
prog llm "def={=>('a one-line plain-English definition of: '++\$0)}"
prog llm "\$def%'entropy'"
prog llm "\$def%'a monad'"

say "the library now holds these reusable parts (persisted across every program above):"
grep -o '"[a-zA-Z_][a-zA-Z0-9_]*": {' "$LIB" | sed 's/[":{ ]//g' | sed 's/^/  · /'

say "the pyramid COMPOUNDS: each round's part joins a growing library the next round reuses."
