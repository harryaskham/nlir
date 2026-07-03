#!/usr/bin/env bash
# nlir-golf · msm0 · #08 — "flashcard" (the last exchange as a Q/A card)
#
# TWO assignments feeding ONE double-quoted template that does BOTH escape
# processing (\n) AND interpolation of two computed values. Read the last user
# question verbatim, summarise the last assistant answer, format as a card:
#
#   q = ^_-1 ; a = ~^-1 ; "Q: $q\nA: $a"
#   │          │           └ double-quoted: \n is a newline, $q/$a interpolated
#   │          └ a = ~^-1   summary of the last ASSISTANT turn  = the answer
#   └─────────── q = ^_-1   the last USER turn, verbatim        = the question
#
# The question stays exact (raw read); only the answer is condensed. Turns any
# exchange into a study flashcard / FAQ entry — and shows "…" doing escapes AND
# interpolation together (raw '…' would do neither).
#
# Real output (claude-sonnet-5) over a process-vs-thread exchange:
#   Q: What's the difference between a process and a thread?
#   A: Processes have isolated memory, while threads share a process's memory and
#      thus require synchronization to prevent race conditions.
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
 {"role":"user","content":"What's the difference between a process and a thread?"},
 {"role":"assistant","content":"A process has its own isolated memory space; threads live inside a process and share its memory, so they're lighter but need synchronization to avoid races."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a one-exchange process-vs-thread Q&A is in the context"
say 'FLASHCARD   q=^_-1 ; a=~^-1 ; "Q: $q\nA: $a"   — verbatim question, summarised answer'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'q=^_-1;a=~^-1;"Q: $q\nA: $a"' --quiet
say 'two assignments + a "…" template doing \n escapes AND $q/$a interpolation.'
