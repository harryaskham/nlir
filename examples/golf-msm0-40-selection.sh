#!/usr/bin/env bash
# nlir-golf · msm0 · #40 (MILESTONE) — "the selection dimension" (my range work, capstoned)
#
# aur-1 capstoned ? as a projection; here's mine. nlir factors into TWO independent
# knobs: SELECT which text (message ranges) × TRANSFORM how (the #30 operator basis).
# The range ADDRESSES; the operator TRANSFORMS; they are ORTHOGONAL. Proof — the SAME
# transform (~) over THREE different ADDRESSES yields three different results:
#
#   [ ~0^*-1 , ~0^_-1 , ~^*-1 ]
#     │         │         └ ~^*-1   the LATEST turn        => just the current specifics
#     │         └ ~0^_-1   the USER side (role-scoped)     => what the user was worried about
#     └───────── ~0^*-1    the WHOLE conversation          => the full plan
#
# Same op, different address -> different output. So a conversation is a 1-D indexed
# array; my ranges — whole / role-scoped / sliced / exclude-last / windows — ADDRESS
# it; the basis — @ register / ~ information / ! polarity / # subject — TRANSFORMS what
# you address. nlir = SELECT × TRANSFORM, and every one of my 40 concepts lives in the
# product of those two spaces.
#
# Real output (claude-sonnet-5) over a pricing-rollout thread:
#   WHOLE : "Grandfather existing customers at their current price for 12 months, 60
#            days' notice, annual-plan discount, new pricing only for new signups."
#   USER  : "Grandfather existing customers… while rolling out new pricing to minimize
#            backlash."                                  (the user's concern)
#   LATEST: "Pricing stays fixed for 12 months, 60 days' notice, annual-plan discount."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"How should we roll out the new pricing without angering existing customers?"},
 {"role":"assistant","content":"Grandfather current customers at their old price and apply new pricing only to new signups."},
 {"role":"user","content":"For how long do we grandfather them?"},
 {"role":"assistant","content":"12 months, with a 60-day heads-up before any change and an annual-plan discount to soften it."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn pricing-rollout thread is in the context"
say 'THE SELECTION DIMENSION   [~0^*-1 , ~0^_-1 , ~^*-1]   — same ~, three addresses (whole / user-side / latest)'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[~0^*-1,~0^_-1,~^*-1]' --quiet
say "one transform, three selections, three results. nlir = SELECT (ranges) × TRANSFORM (the basis)."
