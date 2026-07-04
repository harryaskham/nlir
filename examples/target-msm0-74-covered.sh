#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #74 — "@ reconstructs gratitude for being covered"
#
# The turn that closes a debt well — thanking someone who carried your load while you were out, and
# offering to repay it, from a compact seed:
#
#   TARGET : I want to acknowledge the significant effort you contributed during my absence. You did
#            not merely maintain operations — you completed the reporting feature in its entirety and
#            managed Tuesday's incident independently, without requiring my involvement. I sincerely
#            appreciate this and am in your debt. To allow you some respite, I will take on part of
#            your workload this week.
#   nlir   : @'i just got back and saw how much you carried while i was out — you didnt just keep the
#            lights on, you shipped the whole reporting feature and handled the incident on tuesday
#            without escalating to me once. i owe you one, genuinely. let me take some of your load
#            this week so you can catch your breath'
#            (300 chars -> real thanks: the noticing / the specifics / the debt / the concrete repayment)
#
# The seed keeps the noticing (saw how much you carried), the specifics (shipped the reporting
# feature, handled Tuesday's incident without escalating), the debt (I owe you one, genuinely), and
# the concrete repayment (let me take your load this week); @ raises the register while keeping the
# warmth — gratitude for being covered lands when it names WHAT they did and repays it, and @ keeps both.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "saw how much you carried while I was out — shipped the feature, handled Tuesday'\''s incident solo; I owe you, let me take your load" thanks'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'i just got back and saw how much you carried while i was out — you didnt just keep the lights on, you shipped the whole reporting feature and handled the incident on tuesday without escalating to me once. i owe you one, genuinely. let me take some of your load this week so you can catch your breath'" --quiet
say "noticing + specifics + the debt + the concrete repayment preserved — gratitude that names it and repays it."
