#!/usr/bin/env bash
# nlir showcase · msm0 · L3/L4 PYRAMID — reusable named PARTS compose into TRAINS
#
# Harry's "pyramid of thought": a PART = a named form (a thought-unit); a TRAIN =
# parts composed via `%`. Short trains expand into exactly what you mean, and the
# library COMPOUNDS — a part built one round is reused the next.
#
#   sq={$0*$0}; $sq↦[…]              a named form, mapped (det, offline)
#   j={$if%($0~>$1,$1~>$0,'false')}  the self-judge — nlir grading nlir, reusable
#   ask={($0)?}; pro={@~$0}          pure-op lenses; compose: $ask%($pro%rant)
#   c=…; [$c, >!$c]                  bind an idea ONCE ($ reads it), reuse it
#
# Pure-op + bare-safe parts AND prose-prompt parts now round-trip (render-with-quotes
# fix bd-4fb6d0 @bc863e1 preserves string literals in named forms). det parts run
# offline (CI-green); llm parts need LITELLM_MASTER_KEY (skipped else).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
HAVE_KEY=0; [ -n "${LITELLM_MASTER_KEY:-}" ] && HAVE_KEY=1

say()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
why()  { printf '   \033[2m(%s)\033[0m\n' "$1"; }
run()  { # MODE EXPR
  if [ "$1" = llm ] && [ "$HAVE_KEY" = 0 ]; then printf '  ~ SKIP (no LITELLM_MASTER_KEY)\n'; return 0; fi
  printf '  => '; "$NLIR" --config "$CFG" --mode "$1" --quiet -e "$2" 2>&1 | tail -1
}

say "L3 PART (det, offline) — name a thought-unit once, map it over a list"
why "sq={\$0*\$0} is a reusable named form; \$sq applies it — proof the pattern runs with no model"
run det 'sq={$0*$0};$sq↦[1,2,3,4]'

say "L3 SELF-JUDGE part — nlir grading nlir (the mutual semantic gate, named + reusable)"
why "j = does A mean B both ways; reuse it to score any candidate against any target"
run llm "j={\$if%(\$0~>\$1,\$1~>\$0,'false')};\$j%('Earth','the third planet from the sun')"

say "L4 TRAIN — bind an idea ONCE, reuse it: the claim + its own devil's advocate"
why "\$c reads the binding; the same c feeds both the statement and its rebuttal"
run llm "c='ship the beta on friday';[\$c,>!\$c]"

say "L4 TRAIN — parts composed via %: rant → professional → question"
why "ask={(\$0)?} and pro={@~\$0} are reusable lenses; \$ask%(\$pro%rant) chains them"
run llm "pro={@~\$0};ask={(\$0)?};\$ask%(\$pro%'why do deploys keep breaking, nobody runs tests first')"

say "L3 PROSE PART (unblocked by bd-4fb6d0) — a named form carrying a SENTENCE instruction"
why "def={@>('a one-line definition of '++\$0)} now round-trips WITH its prose string; reuse it on anything"
run llm "def={@>('a one-line definition of '++\$0)};\$def%'idempotence'"

say "L4 PROSE TRAIN — a named classifier drives a decision (triage-in-a-part)"
why "route={\$if%(\$0~>'urgent','escalate','queue')} — reuse it to route ANY item by meaning"
run llm "route={\$if%(\$0~>'urgent','escalate','queue')};\$route%'payments are failing in production'"

say "the library COMPOUNDS: a part built this round is reused next — pure-op, bare-safe, AND prose parts all round-trip now."
