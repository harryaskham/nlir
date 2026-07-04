#!/usr/bin/env bash
# nlir-golf · msm0 · #64 — "the pipeline" (a named sequential transform chain)
#
# Where fanout (#15) splits one value into PARALLEL branches, the pipeline threads it through
# STAGES — each naming its input, so a deep nesting becomes a readable chain you can reuse from:
#
#   raw=^*-1 ; sum=~$raw ; top=#$sum ; "[$top] $sum"
#   │          │           │           └ format: reuse BOTH the topic AND the summary
#   │          │           └ top = #$sum   the topic OF the summary          (stage 3)
#   │          └ sum = ~$raw   summarise the raw message                     (stage 2)
#   └───────── raw = ^*-1   read the last message                           (stage 1)
#
#   => "[Magic-link login option] Add a magic-link login option and allow exploration before verifying."
#
# Naming the stages turns the deep nesting #(~(^*-1)) into a legible line — and, crucially, lets
# you REUSE an intermediate: $sum feeds both the topic extraction and the final template. The DAG
# as a LINE (this) vs a FAN (#15): same assignment machinery, two shapes. This is the readable
# form of every multi-op concept in the catalog.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"The onboarding flow loses 60% of users at the email verification step."},
 {"role":"assistant","content":"Add a magic-link option and let them explore before verifying."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE PIPELINE   raw=^*-1 ; sum=~$raw ; top=#$sum ; "[$top] $sum"   (read -> summarise -> topic -> format)'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'raw=^*-1;sum=~$raw;top=#$sum;"[$top] $sum"' --quiet
say "named stages = a readable chain; $sum is reused in BOTH the topic and the output. The DAG as a line, not a fan."
