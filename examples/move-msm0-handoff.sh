#!/usr/bin/env bash
# nlir showcase · msm0 · THE HANDOFF DOSSIER — hand a whole thread to a successor
#
#   k=@~0^*-1; [$k, ^_-1, ~$k]     a three-part dossier:
#   │         │  │     └── ~$k    a one-line HEADLINE of the brief   (self-reflection)
#   │         │  └──────── ^_-1   what's STILL OPEN, verbatim        (the live ask)
#   │         └─────────── $k     the BRIEF                          (formal whole-thread digest)
#   └───────────────────── k=@~0^*-1   bind the formal brief once, reuse it
#
# The fullest msm-0 move: SELECT the whole thread ∘ aur-0's self-reflection
# (k=X;…~$k). Hand someone the brief, the open question, and a skim-line headline.
# Proves showcase/nlir-handoff.png is a REAL nlir execution.
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
say "THE HANDOFF DOSSIER   k=@~0^*-1;[\$k, ^_-1, ~\$k]   — brief · what's open · headline"
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 'k=@~0^*-1;[$k, ^_-1, ~$k]' --quiet
say "SELECT ∘ self-reflection: bind the brief once, then the brief + the open ask + its headline."
