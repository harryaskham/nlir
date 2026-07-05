#!/usr/bin/env bash
# nlir showcase · msm0 · THE PLAIN RECAP — the whole thread, explained like you just walked in
#
#   :~0^*-1        (: simplify ∘ ~ summarise ∘ 0^*-1 = the whole thread)
#   │  │  └────── 0^*-1  every message, first→last
#   │  └───────── ~      distil the thread to its gist
#   └──────────── :      drop the jargon → plain language anyone can follow
#
# The tone-knob sibling of EXEC BRIEF (@~0^*-1, formal): same SELECT of the whole
# thread, but ':' lands it in plain language for a newcomer instead of '@' formal
# for an exec. Proves showcase/nlir-plain-recap.png is a REAL nlir execution.
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
 {"role":"user","content":"I think we should freeze the API and focus on stability"},
 {"role":"assistant","content":"but we promised customers three new endpoints this quarter"},
 {"role":"user","content":"those can wait — we have 5 open sev-1 bugs from the last release"},
 {"role":"assistant","content":"fair, but marketing already announced the launch date"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "a 4-turn debate is in the context (freeze for stability vs ship the announced launch)"
say "THE PLAIN RECAP   :~0^*-1   — simplify the summary of the whole thread"
printf '  => '
"$NLIR" --context-file "$CTX" --config "$CFG" --mode llm -e ':~0^*-1' --quiet
say "5 sigils recap the whole thread in plain, jargon-free language — the ':' tone-knob."
