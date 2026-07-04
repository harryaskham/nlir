#!/usr/bin/env bash
# nlir-golf · msm0 · #50 (MILESTONE) — "mission control" (SELECT × TRANSFORM, full stretch)
#
# The grand capstone: one expression reads FOUR addresses of a conversation and templates
# a complete live dashboard — the whole night's thesis in a single line.
#
#   t=#~0^*-1 ; u=~0^_-1 ; a=~0^-1 ; n=^*-1 ; "=== $t ===\nAsked: $u\nAdvised: $a\nLatest: $n"
#   │           │          │         │         └ interpolation ASSEMBLES the four into a card
#   │           │          │         └ n = ^*-1    the LATEST turn (any role)   = where it stands
#   │           │          └ a = ~0^-1   the ASSISTANT channel, summarised      = the advice
#   │           └ u = ~0^_-1   the USER channel, summarised                      = what they want
#   └────────── t = #~0^*-1    the WHOLE-thread topic (crux)                     = the title
#
# Four channels of the SELECT alphabet (#48), each TRANSFORMED (# topic / ~ summary),
# reused-free via assignment, interpolated into one dashboard. This IS nlir = SELECT ×
# TRANSFORM (#40): a range ADDRESSES, operators TRANSFORM, assignment REUSES, "…"
# ASSEMBLES. Every one of my 50 concepts is a special case of this line.
#
# Real output (claude-sonnet-5) over an AWS-cost thread:
#   === AWS cost reduction ===
#   Asked:   The team wants to reduce a doubled AWS bill — mainly RDS costs — without downtime.
#   Advised: Rightsize idle resources, archive cold data to Glacier, buy reserved instances
#            for steady workloads, and use read replicas over oversized primaries.
#   Latest:  Can we do this without downtime?
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
 {"role":"user","content":"We need to cut our AWS bill — it doubled last quarter."},
 {"role":"assistant","content":"Start with rightsizing idle instances and moving cold data to S3 Glacier."},
 {"role":"user","content":"Most of the cost is the RDS fleet actually."},
 {"role":"assistant","content":"Then buy reserved instances for the steady baseline and use read replicas instead of oversized primaries."},
 {"role":"user","content":"Can we do this without downtime?"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 5-turn AWS-cost thread is in the context"
say 'MISSION CONTROL   t=#~0^*-1 ; u=~0^_-1 ; a=~0^-1 ; n=^*-1 ; "=== $t ===\nAsked: $u\nAdvised: $a\nLatest: $n"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;u=~0^_-1;a=~0^-1;n=^*-1;"=== $t ===\nAsked: $u\nAdvised: $a\nLatest: $n"' --quiet
say "a range ADDRESSES, operators TRANSFORM, assignment REUSES, \"…\" ASSEMBLES. nlir = SELECT × TRANSFORM."
