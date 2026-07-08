#!/usr/bin/env bash
# nlir showcase · msm3 · COMPOSABLE PERSISTENT LIBRARY — the pyramid, literally
#
# Harry's "build up a pyramid of thought": each level reuses the parts BELOW it.
# nlir does this for real — a persisted part can REFERENCE OTHER persisted parts,
# resolved at apply-time, across SEPARATE programs. So you grow a library bottom-up:
# base parts, then parts built ON those, then a top part that composes the stack —
# and calling the top part unfolds the whole pyramid.
#
#   nlir --context-file lib -e "label={('['++$0++']')}"          # L1 base
#   nlir --context-file lib -e "card={('title '++($label%$0))}"  # L2 uses $label
#   nlir --context-file lib -e "$card%'hi'"                       # SEPARATE run → title [hi]
#
# Properties (all verified): arbitrary chain depth (a→b→c), ORDER-INDEPENDENT
# (define a user before the part it calls — resolution is at apply-time), and
# generative (llm) parts compose the same way. Enabled by bd-4fb6d0 (parts persist
# with their literals intact). det rounds run OFFLINE (CI-green); llm gates on key.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
HAVE_KEY=0; [ -n "${LITELLM_MASTER_KEY:-}" ] && HAVE_KEY=1

LIB="$(mktemp -t nlir-pyramid-lib.XXXXXX.json)"
trap 'rm -f "$LIB"' EXIT

say()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
why()  { printf '   \033[2m(%s)\033[0m\n' "$1"; }
prog() { # MODE EXPR — a standalone nlir program sharing the persistent library
  if [ "$1" = llm ] && [ "$HAVE_KEY" = 0 ]; then printf '  ~ SKIP (no LITELLM_MASTER_KEY)\n'; return 0; fi
  printf '  $ nlir -e %q\n  => ' "$2"
  "$NLIR" --config "$CFG" --context-file "$LIB" --mode "$1" --quiet -e "$2" 2>&1 | tail -1
}

say "BUILD THE PYRAMID BOTTOM-UP (det, offline) — each level a SEPARATE program, persisted"
why "L1 base part: wrap in brackets"
prog det "label={('['++\$0++']')}"
why "L2: 'card' USES \$label internally — a part built on a part"
prog det "card={('title '++(\$label%\$0))}"
why "L3: 'banner' composes \$card — the top of a 3-level stack"
prog det "banner={('=== '++(\$card%\$0)++' ===')}"

say "CALL THE TOP PART (a SEPARATE program) — the whole pyramid unfolds"
why "\$banner → \$card → \$label, all resolved from the persistent library at apply-time"
prog det "\$banner%'hello'"

say "ORDER-INDEPENDENT — define a user BEFORE the part it calls (apply-time resolution)"
why "outer references \$inner, but inner is persisted AFTER; calling outer still works"
prog det "outer={('<'++(\$inner%\$0)++'>')}"
prog det "inner={('*'++\$0++'*')}"
prog det "\$outer%'ok'"

say "GENERATIVE composition (llm) — a part that composes a generative part, cross-program"
why "entry USES the generative \$def; both persisted, composed live in a later program"
prog llm "def={=>('a 5-word definition of: '++\$0)}"
prog llm "entry={(\$0++' — '++(\$def%\$0))}"
prog llm "\$entry%'entropy'"

say "the library holds a composable stack of parts:"
grep -o '"[a-zA-Z_][a-zA-Z0-9_]*": {' "$LIB" | sed 's/[":{ ]//g' | sed 's/^/  · /'

say "THE PYRAMID, literally: parts build on parts, persisted — each round's part is a rung the next stands on."
