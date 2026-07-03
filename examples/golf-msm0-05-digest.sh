#!/usr/bin/env bash
# nlir-golf · msm0 · #05 — "titled digest" (one summary → a title + a body)
#
# Assignment shares an expensive value across a structured output. Summarise the
# whole conversation ONCE into `s`, then emit a two-line card: the SUBJECT of the
# summary is the title, the summary itself is the body:
#
#   s = ~0^*-1 ; [ #$s , $s ]
#   │             │      └ $s   the summary  = the BODY
#   │             └────── #$s   subject($s)  = the TITLE
#   └─────────────────── s = ~0^*-1  summarise the ENTIRE conversation, stored once
#
# One LLM summary, reused twice (=/$name DAG value-reuse). Turns a debugging chat
# into an auto-filed bug report / PR: a crisp title over a one-paragraph body.
#
# Real output (claude-sonnet-5) over an Android-crash thread:
#   TITLE: Android launch crashes from a missing feature-flag default
#   BODY : The 3.2 update causes Android launch crashes from a missing feature-flag
#          default in onboarding, requiring a 3.2.1 hotfix with a safe default and gate.
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
 {"role":"user","content":"The mobile app crashes on launch for some Android users after the 3.2 update."},
 {"role":"assistant","content":"Likely a null in the new onboarding flow; check crash logs for the stack trace."},
 {"role":"user","content":"Crashlytics points to a missing feature-flag default."},
 {"role":"assistant","content":"Add a safe default for the flag and gate the onboarding behind it; ship a 3.2.1 hotfix."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn Android-crash debugging thread is in the context"
say "TITLED DIGEST   s=~0^*-1 ; [#\$s , \$s]   — one summary, reused as TITLE + BODY"
echo "  --- [ title , body ] ---"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 's=~0^*-1;[#$s,$s]' --quiet
say "one LLM summary shared via =/\$name — an auto-filed bug report from a chat."
