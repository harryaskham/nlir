#!/usr/bin/env bash
# nlir-golf · msm0 · #53 — "the evolution" (bookend a conversation to see it drift)
#
# Conversations change their own minds. This bookends one — the FIRST question against
# where it LANDED — so the drift is visible at a glance:
#
#   a=~^_0 ; b=~^*-1 ; "OPENED: $a\n\nCLOSED: $b"
#   │        │          └ template the two temporal edges into a then/now card
#   │        └ b = ~^*-1   the LAST turn (any role), summarised   = where it landed
#   └──────── a = ~^_0     the FIRST user turn, summarised         = how it began
#
# Two role-addressed reads (#48 alphabet) at the temporal EDGES of the thread, each
# summarised, interpolated into a card. When a thread reverses its own premise, the
# bookend makes the reversal legible — the diff between where you started and where you
# are, which no single snapshot (#50 mission-control) shows.
#
# Real output (claude-sonnet-5) over a billing thread that starts "rewrite in Go?" and
# ends "just fix the queries":
#   OPENED: The team is considering whether to rewrite the billing service in Go.
#   CLOSED: Let's fix the queries and keep the service running.
#   (the rewrite idea, raised then abandoned — the whole arc in two lines)
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
 {"role":"user","content":"Should we rewrite the billing service in Go?"},
 {"role":"assistant","content":"Maybe — but first find out why it's slow."},
 {"role":"user","content":"Profiling shows it's all N+1 queries, not the language."},
 {"role":"assistant","content":"Then a rewrite won't help; batch the queries and add a cache."},
 {"role":"user","content":"Right, let's fix the queries and keep the service."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a billing thread that opens on 'rewrite in Go?' and closes on 'just fix the queries' is in context"
say 'THE EVOLUTION   a=~^_0 ; b=~^*-1 ; "OPENED: $a\n\nCLOSED: $b"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'a=~^_0;b=~^*-1;"OPENED: $a\n\nCLOSED: $b"' --quiet
say "the first question vs the final resolution — the drift a single snapshot can't show."
