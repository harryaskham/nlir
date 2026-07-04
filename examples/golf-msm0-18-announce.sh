#!/usr/bin/env bash
# nlir-golf · msm0 · #18 — "announcement" (input-side interpolation of a decision)
#
# Read the DECISION, weave it into an announcement prompt, and let @ broadcast it:
#
#   d=~^*-1 ; @"team announcement — here's what we've decided: $d"
#   │         └ @( "team announcement — here's what we've decided: <decision>" )
#   │           formalise the CONSTRUCTED prompt into a finished notice
#   └──────── d = ~^*-1   summary of the latest turn (any role) = the decision made
#
# Distinct from #17 follow-up (topic → a question): here the LATEST turn (^*-1, the
# user's call) is spliced into an announcement frame, so "let's do X" becomes a
# polished, sendable team notice. Input-side interpolation writing a broadcast.
#
# Real output (claude-sonnet-5) over a four-day-week decision thread:
#   "Team Announcement: Effective next month, Fridays will be designated as
#    non-working days, subject to review in the third quarter."
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
 {"role":"user","content":"Should we adopt a four-day work week for the engineering team?"},
 {"role":"assistant","content":"Trial it for one quarter with the same delivery targets and measure throughput and burnout."},
 {"role":"user","content":"Let's do it — Fridays off starting next month, we'll review in Q3."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 3-turn four-day-week decision thread is in the context"
say 'ANNOUNCEMENT   d=~^*-1 ; @"team announcement — here'\''s what we'\''ve decided: $d"'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'd=~^*-1;@"team announcement — here is what we have decided: $d"' --quiet
say "the decision spliced into an announcement frame, then formalised into a sendable notice."
