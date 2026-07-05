#!/usr/bin/env bash
# nlir showcase · msm0 · EXEC BRIEF — a messy incident thread → one VP-ready paragraph
#
#   @~0^*-1        (@ formalise ∘ ~ summarise ∘ 0^*-1 = the whole thread)
#   │  │  └────── 0^*-1  every message, first→last
#   │  └───────── ~      distil the thread to its gist
#   └──────────── @      lift it to a professional register
#
# The "brief the VP in 10 minutes" move: whole conversation → one forwardable
# paragraph. Formal-register companion to CATCH-UP. Proves the showcase card
# showcase/nlir-exec-brief.png is a REAL nlir execution, not hand-authored text.
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
say "a 5-turn incident thread is in the context (500s → 2026-expiry bug → rollback? → hotfix)"
say "EXEC BRIEF   @~0^*-1   — formalise the summary of the whole thread"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '@~0^*-1' --quiet
say "7 sigils turn a messy incident thread into one forwardable, VP-ready paragraph."
