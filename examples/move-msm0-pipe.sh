#!/usr/bin/env bash
# nlir showcase · msm0 · WHY NLIR, NOT A PROMPT — det+fuzzy in a unix pipe
#
# The signature nlir can't be replaced by "just ask an LLM": it sits MID-PIPE and
# MIXES exact computation with fuzzy judgment in one expression. stdin arrives as
# $_stdin, `//` splits it to a list of lines, `↦`/`⊘` map/fold with det OR llm steps.
#
#   {$0+$1}⊘($_stdin//"\n")            fold: LLM reads each line's number, `+` sums EXACTLY
#   {$contains%($0,"X")}↦(…) then ⊘    map a per-line test, then a det count/branch
#   #($_stdin//"\n")                   fold to the ONE theme (semantic awk)
#
# Each example fails sgu24-app's test — "why isn't this just one LLM prompt?" — because
# a raw model can't do reliable exact arithmetic, and no single unix tool (grep/awk/wc)
# can do the fuzzy half. The det example runs offline; the llm ones need
# LITELLM_MASTER_KEY (skipped without it, so det CI stays green).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
HAVE_KEY=0; [ -n "${LITELLM_MASTER_KEY:-}" ] && HAVE_KEY=1

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
why() { printf '   \033[2m(%s)\033[0m\n' "$1"; }
# runpipe INPUT MODE EXPR — pipe INPUT through nlir; skip llm cleanly with no key
runpipe() {
  if [ "$2" = llm ] && [ "$HAVE_KEY" = 0 ]; then printf '  ~ SKIP (no LITELLM_MASTER_KEY)\n'; return 0; fi
  printf '  => '; printf '%s' "$1" | "$NLIR" --config "$CFG" --mode "$2" --quiet -e "$3" 2>&1 | tail -1
}

say "COUNT-AND-BRANCH (DET, offline) — page if >=2 lines mention ERROR"
why "det count over a per-line test -> threshold -> branch: grep+wc+if in one pipe stage"
runpipe "$(printf 'boot ok\nERROR disk full\nwarn cpu\nERROR oom killed\n')" det \
  '?%({$0+$1}⊘({$contains%($0,"ERROR")}↦($_stdin//"\n"))>=2,"PAGE on-call","all clear")'

say "FUZZY-SUM (LLM) — sum fuzzily-worded amounts, exactly"
why "the model extracts each count; the EXACT + sums it — a raw prompt can't be trusted to add"
runpipe "$(printf '3 apples\n5 oranges\n2 pears\n')" llm '{$0+$1}⊘($_stdin//"\n")'

say "SEMANTIC GREP -> COUNT (LLM) — how many reviews are complaints"
why "fuzzy per-line judgment, then an EXACT count — grep can't judge, a prompt can't count reliably"
runpipe "$(printf 'love the new ui\nit keeps crashing on save\nfast support\nbilling charged me twice\n')" llm \
  '{$0+$1}⊘({$0~>"a complaint"}↦($_stdin//"\n"))'

say "SEMANTIC AWK (LLM) — the one theme across recent commits"
why "fold a list of commits to their shared subject: awk with understanding"
runpipe "$(git log --oneline -6 2>/dev/null)" llm '#($_stdin//"\n")'

say "each mixes exact + fuzzy in ONE pipe stage — what no single tool, and no single prompt, does."
