#!/usr/bin/env bash
# nlir-golf · msm0 · #72 — "the fork" (the disjunctive join | — & 's sister)
#
# nlir has TWO join operators, one for each logic. & is CONJUNCTION (do all of them); | is
# DISJUNCTION (pick one):
#
#   'roll back' & 'hotfix' & 'wait'   =>  "roll back and hotfix and wait"   (all together — a conjunction)
#   'roll back' | 'hotfix' | 'wait'   =>  "roll back or hotfix or wait"     (choose one — a fork)
#
# Same three operands, two connectives, two meanings: & braids them into one combined thing, | lays
# them out as mutually-exclusive options. And the fork transforms like anything else:
#
#   @('ship it' | 'cut scope')   =>  "Ship it, or reduce the scope."   (a formal decision prompt)
#
# Where #26 was the algebra of & (the ordered, dup-keeping conjunctive join), this is its sister | —
# the disjunctive join, the AND/OR duality underneath every choice you present. Two logics, two sigils.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
r() { printf '  %-34s => ' "$1"; "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }
say "two joins, two logics — & is conjunction (all), | is disjunction (choose):"
r "'roll back'&'hotfix'&'wait'"
r "'roll back'|'hotfix'|'wait'"
say "and the fork transforms — @('ship it'|'cut scope'):"
r "@('ship it'|'cut scope')"
say "& braids into one, | forks into options — the AND/OR duality under every choice."
