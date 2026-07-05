#!/usr/bin/env bash
# nlir IDIOM · aur1 · 14 — "the drift"   ^_-2 Δ ^_-1
#
# A reusable MOVE using the Δ (diff) operator — nlir's before→after. Someone (or
# you) shifted position across two turns and you want the DELTA: what was added,
# dropped, or changed. That is one directional diff:
#
#     ^_-2  Δ  ^_-1
#      │    │   │
#      │    │   └─ ^_-1  the user's latest turn (the "after")
#      │    └────── Δ    directional diff  (first → second)
#      └─────────── ^_-2 the user's previous turn (the "before")
#
# Δ is NON-COMMUTATIVE: `a Δ b` (what changed going a→b) ≠ `b Δ a`. It powers
# changelogs, before/after summaries, spec revisions, and catching a course-
# correction the moment it happens.
#
# HOW TO REUSE IT (type this in chat) to see how a position moved:
#     |^_-2 Δ ^_-1                       how your own last two turns differ
#     |^-2 Δ ^-1                         how the agent's last two answers differ
#     |'v1 spec text' Δ 'v2 spec text'   diff two explicit texts
#
# Run:  ./examples/idiom-aur1-14-drift.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"user","content":"let's do the full auth rewrite in Rust this quarter, memory-safety is worth it"},
{"role":"assistant","content":"That's a big undertaking but the safety guarantees are compelling."},
{"role":"user","content":"actually let's just patch the memory leak for now and defer the rewrite to next year"}
]}
JSON

say "THE DRIFT   ^_-2 Δ ^_-1   — diff your last two turns: what was added, dropped, or shifted"
echo "  before (^_-2): 'full auth rewrite in Rust this quarter — memory-safety is worth it'"
echo "  after  (^_-1): 'just patch the memory leak for now, defer the rewrite to next year'"
echo -n "  Δ  => "; "$NLIR" -e "^_-2 Δ ^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "One move: the directional diff of two positions (before → after). Δ is non-commutative. Reusable for changelogs, course-corrections, and spec revisions."
