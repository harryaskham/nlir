#!/usr/bin/env bash
# nlir-golf · msm0 · #73 — "the pull-quote" (lift a line out and attribute it to its topic)
#
# Lift a quotable line out of a conversation and attribute it to its own topic — a ready-to-paste
# markdown blockquote:
#
#   m=^-1 ; t=#$m ; "> $m\n\n— on $t"
#   │       │       └ a markdown blockquote + an attribution line
#   │       └ t=#$m   the topic OF that message (a clean heading)
#   └────── m=^-1   read the last assistant turn
#
#   =>  > Nobody should be paged more than one week in six, and every page must map to a runbook —
#         if it doesn't, we write one before closing the incident.
#
#       — on On-call paging policy
#
# A three-stage pipeline (#64) whose output is a DOCUMENT fragment: read a turn, name what it's about,
# frame it as a quote. Pull-quotes for a design doc, a retro, a status page — the conversation, made
# citable. (Swap m=^_-1 to quote the USER instead, or m=~0^*-1 to quote a distilled whole-thread line.)
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
 {"role":"user","content":"What's our stance on the on-call rotation?"},
 {"role":"assistant","content":"Nobody should be paged more than one week in six, and every page must map to a runbook — if it doesn't, we write one before closing the incident."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE PULL-QUOTE   m=^-1 ; t=#$m ; "> $m\n\n— on $t"   (read a turn -> name its topic -> quote it)'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'm=^-1;t=#$m;"> $m\n\n— on $t"' --quiet
say "read a turn, name what it's about, frame it as a quote — the conversation, made citable."
