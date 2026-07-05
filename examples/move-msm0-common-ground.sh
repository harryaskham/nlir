#!/usr/bin/env bash
# nlir showcase · msm0 · THE COMMON GROUND — merge both role channels → the synthesis
#
#   ~(0^_-1 & 0^-1)        the flip-side of TWO-SIDES:
#   │  │      └── 0^-1    every ASSISTANT turn   (our side)    ^  = assistant view
#   │  └───────── 0^_-1   every USER turn        (their side)  ^_ = user view
#   └──────────── ~( … & … )  merge both sides + distil → where the debate LANDS
#
# TWO-SIDES `[~0^_-1, ~0^-1]` keeps the sides apart; THE COMMON GROUND merges them
# into the resolution. Honest: if the thread hasn't converged, it says so ("still
# debating…"). Proves showcase/nlir-common-ground.png is a REAL nlir execution.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

CTX="$(mktemp -u "${TMPDIR:-/tmp}/nlir-showcase-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"we need the payments feature shipped by friday"},
 {"role":"assistant","content":"engineering needs two weeks for proper testing and a security review"},
 {"role":"user","content":"can we ship a beta friday and GA in two weeks?"},
 {"role":"assistant","content":"a flagged beta friday works if we limit it to internal users first"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn negotiation is in the context (ship-by-Friday vs needs-two-weeks-to-test)"
say "THE COMMON GROUND   ~(0^_-1 & 0^-1)   — merge their side & ours, distil the resolution"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '~(0^_-1 & 0^-1)' --quiet
say "role-channel MERGE: where the two sides actually land (vs TWO-SIDES' split)."
