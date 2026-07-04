#!/usr/bin/env bash
# nlir-golf · msm0 · #15 — "fanout" (one summary, three lenses, computed once)
#
# The point of assignment is DAG-reuse: compute an expensive value ONCE, then fan
# it out. Summarise the thread into `s`, then view it three ways in a list:
#
#   s=~0^*-1 ; [ #$s , $s , !$s ]
#   │           │     │    └ !$s  the summary NEGATED = the mirror-image counterargument
#   │           │     └ $s   the summary itself       = the position
#   │           └ #$s   subject of the summary        = the topic
#   └────────── s = ~0^*-1   ONE summary call, reused three times (not three calls)
#
# The `!$s` lens is the striking one: it inverts every clause of the position
# (simplifies↔complicates, own-DB↔shared-DB), giving you the steelmanned opposite
# for free — a built-in devil's advocate over a value the stack already holds.
#
# Real output (claude-sonnet-5) over a shared-DB-vs-per-service thread:
#   Database-per-service architecture (in microservices)
#   Sharing one DB simplifies ops but couples services… each service should have its
#     own database and rely on events/read models, accepting eventual consistency.
#   Sharing one DB complicates ops but decouples services… each service should share
#     the database and rely on cross-service joins, rejecting eventual consistency.
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
 {"role":"user","content":"Should we make all microservices share one database to simplify ops?"},
 {"role":"assistant","content":"A shared DB couples services and creates a single point of failure; prefer a database per service."},
 {"role":"user","content":"But cross-service joins get painful."},
 {"role":"assistant","content":"Use events and read models per service instead of joins; accept eventual consistency."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn shared-DB-vs-per-service design thread is in the context"
say 'FANOUT   s=~0^*-1 ; [#$s , $s , !$s]   — one summary, three lenses: topic / position / inverse'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 's=~0^*-1;[#$s,$s,!$s]' --quiet
say "the summary runs ONCE then fans out; !\$s inverts every clause — a free devil's advocate."
