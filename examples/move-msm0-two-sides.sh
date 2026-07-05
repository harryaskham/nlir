#!/usr/bin/env bash
# nlir showcase · msm0 · THE TWO-SIDES — split a debate by ROLE (their side vs our side)
#
#   [~0^_-1, ~0^-1]        role-channel SELECT, one position per side:
#   │ │  └────── ~0^-1    every ASSISTANT turn, distilled   (our side)   ^  = assistant view
#   │ └───────── ~0^_-1   every USER turn, distilled        (their side) ^_ = user view
#   └─────────── [a, b]   emit both positions
#
# The role-channel SELECT (vs the time-based ranges of CATCH-UP / EXEC-BRIEF):
# ^ = assistant, ^_ = user, ^* = all, ^/ = system (config views:); a range over a
# view (0…-1) selects every message of that role. Proves showcase/nlir-two-sides.png.
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
say "THE TWO-SIDES   [~0^_-1, ~0^-1]   — distil their side (^_ user) and our side (^ assistant)"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[~0^_-1, ~0^-1]' --quiet
say "role-channel SELECT: ^_ user / ^ assistant — each party's position across the whole thread."
