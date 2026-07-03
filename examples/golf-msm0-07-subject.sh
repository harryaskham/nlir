#!/usr/bin/env bash
# nlir-golf · msm0 · #07 — "subject line" (interpolate an LLM value into a template)
#
# nlir can mix an LLM-COMPUTED value into literal text via double-quote `"$name"`
# interpolation (nobody's golfed interpolation). Extract the conversation topic,
# store it, then template it into a header:
#
#   t = #~0^*-1 ; "re: $t"
#   │              └ "re: $t"  a quoted string with $t interpolated at eval time
#   └───────────── t = #~0^*-1  subject(summary(whole chat)) = the topic, stored
#
# So an LLM result flows into deterministic string templating — auto-drafts a
# reply SUBJECT LINE from any conversation. (Raw '…' would keep $t literal; only
# "…" interpolates.)
#
# Real output (claude-sonnet-5) over a usage-based-billing thread:
#   re: Usage-based billing
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
 {"role":"user","content":"Can we switch the billing system from monthly to usage-based pricing?"},
 {"role":"assistant","content":"Yes, but it needs metering, a new invoice pipeline, and clear customer comms."},
 {"role":"user","content":"Let's scope the metering piece first."},
 {"role":"assistant","content":"Instrument the API gateway to emit per-call usage events into a billing ledger."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn usage-based-billing thread is in the context"
say 'SUBJECT LINE   t=#~0^*-1 ; "re: \$t"   — topic into a templated reply header'
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;"re: $t"' --quiet
say 'an LLM-computed topic flows into "$name" string interpolation. Auto-subject.'
