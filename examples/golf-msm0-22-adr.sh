#!/usr/bin/env bash
# nlir-golf · msm0 · #22 — "ADR" (an architecture decision record from a thread)
#
# Turn a decision thread into a filed ADR — title, the context that framed it, and
# the decision reached — by reading three positions:
#
#   t=#~0^*-1 ; c=~^0 ; d=~^*-1 ; "# $t\n\nContext: $c\n\nDecision: $d"
#   │           │       │          └ markdown ADR template
#   │           │       └ d = ~^*-1   the LATEST turn (any role) = the DECISION
#   │           └ c = ~^0    the FIRST assistant turn = the CONTEXT / trade-off framing
#   └────────── t = #~0^*-1  topic of the whole thread = the TITLE
#
# Forward-looking cousin of #13 postmortem (which reads report → fix, backward):
# an ADR reads context → decision, forward. Three temporal reads, a different format.
#
# Real output (claude-sonnet-5) over a build-vs-buy feature-flag thread:
#   # Feature-flag system
#
#   Context: Buying a solution like LaunchDarkly delivers faster value than building
#   one, which only makes sense at large scale or for unusual requirements.
#
#   Decision: The team agreed to adopt LaunchDarkly and revisit the decision once
#   the engineering team reaches 50 people.
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
 {"role":"user","content":"Should we build our own feature-flag system or buy one?"},
 {"role":"assistant","content":"Buying (e.g. LaunchDarkly) is faster to value and battle-tested; building only pays off at large scale or with unusual needs."},
 {"role":"user","content":"We're a 12-person team shipping weekly."},
 {"role":"assistant","content":"At that size, buy: the ops burden of building isn't worth it; revisit only if costs balloon."},
 {"role":"user","content":"Agreed, let's adopt LaunchDarkly and revisit at 50 engineers."}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 5-turn build-vs-buy feature-flag decision thread is in the context"
say 'ADR   t=#~0^*-1 ; c=~^0 ; d=~^*-1 ; "# $t\n\nContext: $c\n\nDecision: $d"'
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e 't=#~0^*-1;c=~^0;d=~^*-1;"# $t\n\nContext: $c\n\nDecision: $d"' --quiet
say "title / context (first answer) / decision (latest turn) — a forward-looking decision record."
