#!/usr/bin/env bash
# nlir showcase · msm0 · THE TONE KNOB — one whole-thread SELECT, three registers
#
#   [@~0^*-1, :~0^*-1, ~0^*-1]     same select (~0^*-1 = the whole thread), three tones:
#   │  └── @~   formal   → brief a VP
#   │  └── :~   plain    → onboard anyone (jargon-free)
#   └───── ~    terse    → a standup line
#
# Teaches the TONE KNOB: the leading operator sets register over an identical
# selection. Proves the grid card showcase/nlir-tone-knob.png is a REAL execution
# (grid cards aren't auto-verified by verify-showcase.py — this is their proof).
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
 {"role":"user","content":"the checkout API is throwing 500s since the 2pm deploy"},
 {"role":"assistant","content":"the new payment validation is rejecting valid cards with a 2026 expiry"},
 {"role":"user","content":"can we just roll back?"},
 {"role":"assistant","content":"rollback is risky — the deploy also shipped the fraud-rule migration that's already live; safer to hotfix the expiry check"},
 {"role":"user","content":"ok do the hotfix but i need to brief the VP in 10 minutes"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 5-turn incident thread is in the context"
say "THE TONE KNOB   [@~0^*-1, :~0^*-1, ~0^*-1]   — same thread, formal / plain / terse"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[@~0^*-1, :~0^*-1, ~0^*-1]' --quiet
say "one SELECT, three registers — the leading op (@/:/~) chooses the audience."
