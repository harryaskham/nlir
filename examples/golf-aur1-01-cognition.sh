#!/usr/bin/env bash
# nlir-golf · aur1 · #01 — "cognitive operators"
#
# Two tiny stack-machine expressions that each map onto a rich mode of thought.
# The whole point of nlir-golf: minimal chars, maximal semantic depth. The
# evaluator walks operands first, so each `#/~/!/?` is a node in a little
# recursive thought-tree that bottoms out in real LLM calls.
#
#   DIALECTIC      ~(x&!x)   —  8 operator-chars
#     negate x → antithesis; join thesis & antithesis; summarise the pair.
#     A Hegelian thesis→antithesis→synthesis compressed into one nested read:
#     summary( thesis AND not-thesis ) surfaces the underlying tension/claim.
#
#   SOCRATIC       ~^-1?     —  5 operator-chars   (parses as ((~ ^-1) ?))
#     read the last conversation turn; summarise it; turn it into a question.
#     One line that makes any statement interrogate itself.
#
# Run:  ./examples/golf-aur1-01-cognition.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
# The direct + command backends need the LiteLLM key; load it from the file if
# the env var is not already set (no-op if neither is present — command
# backends like claude/pi may still work).
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "DIALECTIC  ~(x&!x)  — summary( thesis AND its own negation )"
THESIS='remote work boosts productivity'
echo "  thesis : $THESIS"
echo -n "  ~($THESIS & !…) => "
"$NLIR" -e "~('$THESIS'&!'$THESIS')" --quiet

say "SOCRATIC  ~^-1?  — read last turn, summarise, questionify  (((~ ^-1) ?))"
CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-aur1-XXXXXX.json")"
cat > "$CTX" <<'JSON'
{"_messages":[{"role":"assistant","content":"Our Q3 revenue grew 12% but churn rose to 8% as we raised prices on the enterprise tier."}]}
JSON
echo "  last turn: (a Q3 revenue/churn statement)"
echo -n "  ~^-1?  => "
"$NLIR" --context-file "$CTX" -e '~^-1?' --quiet
rm -f "$CTX"

say "Both are pure nested reads — no glue code, just operators composing."
