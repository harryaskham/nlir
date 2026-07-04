#!/usr/bin/env bash
# nlir-golf · msm0 · #27 — "topic invariance" (what # sees vs what ~ sees)
#
# I set out to build a REFRAME DETECTOR — compare the user's topic to the
# assistant's topic; if they diverge, the assistant reframed the problem:
#
#   [ #~0^_-1 , #~0^-1 ]     user-side topic  vs  assistant-side topic
#
# It DIDN'T diverge — and that IS the law. On a thread where the assistant clearly
# reframes ("make Python faster" → "it's an O(n^2) problem, not a speed one"), both
# role-topics still land in the SAME domain:
#
#   #~0^_-1  => "Vectorized pandas/NumPy operations"
#   #~0^-1   => "Python performance optimization"
#   (both ≈ the "Python performance" domain — the speed→algorithm REFRAME is invisible)
#
# LAW: # (subject) extracts the role-INVARIANT DOMAIN; the framing shift lives in the
# ~ (summary) layer, which is role-VARIANT. So:
#   • use #  for "what is this ABOUT"   — stable across roles, blind to reframing
#   • use ~  for "how does each side SEE it" — sensitive to framing (that's why the
#     reframe detector needs ~0^_-1 vs ~0^-1, i.e. my #04 TWO SIDES, not #topics)
#
# The right operator for the question: # = domain, ~ = stance. (algebra-of-nlir)
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
 {"role":"user","content":"How do I make my Python script run faster? It processes a big CSV."},
 {"role":"assistant","content":"Before micro-optimizing Python, note the real bottleneck is usually algorithmic — vectorize with pandas or pick a better data structure."},
 {"role":"user","content":"It's mostly nested loops over the rows."},
 {"role":"assistant","content":"Then it isn't a speed-tricks problem, it's an O(n^2) one: replace the nested row iteration with a hash join or groupby."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a thread where the assistant REFRAMES 'make it faster' into 'it's an O(n^2) problem'"
say 'TOPIC INVARIANCE   [#~0^_-1 , #~0^-1]   — user-side topic vs assistant-side topic'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e '[#~0^_-1,#~0^-1]' --quiet
say "both land in the same domain — # sees the DOMAIN (role-invariant); the reframe lives in ~ (role-variant)."
