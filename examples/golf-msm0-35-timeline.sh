#!/usr/bin/env bash
# nlir-golf · msm0 · #35 — "the sliding window" (a narrative timeline of a thread)
#
# Three SEQUENTIAL sub-range summaries, kept SEPARATE — a timeline of how a
# discussion PROGRESSED, beat by beat:
#
#   [ ~0^*1 , ~2^*3 , ~4^*-1 ]
#     │        │        └ ~4^*-1  the LATE turns   = beat 3 (result / refinement)
#     │        └ ~2^*3   the MIDDLE turns          = beat 2 (root cause / the fix)
#     └───────── ~0^*1   the EARLY turns           = beat 1 (problem / first diagnosis)
#
# Distinct from #14 hierarchical (which MERGES the windows into one gist): here each
# window stays its own line, so you read the ARC — the story of a debugging session,
# not just its conclusion.
#
# Real output (claude-sonnet-5) over a 6-turn mobile cold-start thread:
#   beat 1: "…8-second cold-start likely caused by a large synchronous bundle and
#            blocking network calls that need profiling and fixing."
#   beat 2: "…loads all config/flags before first paint; instead defer non-critical
#            config and lazy-load flags after rendering a skeleton."
#   beat 3: "…sped up to 2s but now wants a 200ms delay before the skeleton so it
#            doesn't flash on fast loads."
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
 {"role":"user","content":"Our app's cold-start time on mobile is 8 seconds. Too slow."},
 {"role":"assistant","content":"Profile the startup; likely a big synchronous bundle and blocking network calls on launch."},
 {"role":"user","content":"Yeah we load the whole config and feature flags before first paint."},
 {"role":"assistant","content":"Defer non-critical config, render a skeleton first, and lazy-load feature flags after paint."},
 {"role":"user","content":"Did that. Now it's 2s but the skeleton flashes."},
 {"role":"assistant","content":"Add a 200ms delay before showing the skeleton so fast loads skip it entirely."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 6-turn mobile cold-start debugging thread is in the context"
say 'SLIDING WINDOW   [~0^*1 , ~2^*3 , ~4^*-1]   — early / middle / late, three beats'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[~0^*1,~2^*3,~4^*-1]' --quiet
say "three sequential windows, kept separate — the STORY of the session, not just its ending."
