#!/usr/bin/env bash
# nlir MACROS · aur1 · 01 — forms with a hole are reusable functions
#
# A form {…} quotes an expression as data (it does NOT run). $0/$1 are argument
# holes; % applies the form to arguments, filling the holes and evaluating. So a
# form is a MACRO — write an idiom once, then apply it to any input:
#
#     {$0 + $1} % (2, 3)          → 5        (two holes, applied to a tuple)
#     {@$0} % 'lmk if any Qs'     → "Please let me know if you have any questions."
#     {~$0} % 'rambling text…'    → the gist, one line
#     {~(>@$0)} % 'ship in Rust'  → the steelman: expand, argue charitably, distil
#     {$0 Δ $1} % (a, b)          → how b shifted from a
#
# The whole nlir phrasebook becomes callable. (Named macros —
# steelman = {~(>@$0)}; steelman % '…' — land with form persistence.)
#
# Run:  ./examples/macro-aur1-01-macros.sh      (set MODEL=direct on a litellm node)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
MODEL="${MODEL:-}"                     # set MODEL=direct on a litellm node; blank = config default
m() { [ -n "$MODEL" ] && printf -- '--model %s' "$MODEL"; }
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { echo "  $1"; echo -n "  → "; $NLIR -e "$1" --config config.example.yaml $(m) --quiet; echo; }

say "DETERMINISTIC MACROS (no key) — a form is a function"
run '{$0 + $1} % (2, 3)'
run '9; {$0} % 7'          # arg-frame hygiene: $0 is the argument, not the stack top

say "LANGUAGE MACROS (needs a model) — the phrasebook, callable"
run "{@\$0} % 'lmk if any Qs'"
run "{~\$0} % 'so basically what I am trying to say is we should just ship Friday and see'"
run "{~(>@\$0)} % 'we should rewrite it in Rust'"
run "{\$0 Δ \$1} % ('we should ship Friday', 'actually let us wait until Monday')"

say "A form {…} is code-as-data; % runs it. Name it and you have a reusable library of moves."
