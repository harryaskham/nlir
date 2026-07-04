#!/usr/bin/env bash
# nlir-golf (target / reverse) · msm0 · #59 — "@ reconstructs a requirements-clarification"
#
# The turn that saves weeks — refusing to build on a vague spec, with a concrete reason and
# a small concrete ask, from a compact seed:
#
#   TARGET : Before commencing development, I require more clearly defined acceptance
#            criteria. At present, the objective "improve search" could encompass anything
#            from optimizing query performance to implementing full semantic search, and
#            these approaches differ by weeks in terms of effort. I propose we allocate 30
#            minutes to precisely determine what "improved" means from the users' perspective.
#   nlir   : @'before i start building this i need clearer acceptance criteria. right now
#            make search better could mean anything from a faster query to full semantic
#            search, and those are weeks apart in effort. can we spend 30 minutes nailing
#            down what better actually means to the users?'
#            (263 chars -> a scope-guard: the ask / the ambiguity / the cost / the small next step)
#
# The seed keeps the ask (clearer criteria before I start), the ambiguity (make search
# better = fast query OR semantic search), the cost (weeks apart), and the concrete next
# step (30 min to define "better" for users); @ raises the register while keeping the
# concreteness — a clarification lands when it shows the ambiguity's cost, and @ keeps that.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'TARGET: a "before I build this, define acceptance criteria — \"better search\" is weeks apart in scope" ask'
printf "  => "
"$NLIR" --config "$CFG" --mode llm -e "@'before i start building this i need clearer acceptance criteria. right now make search better could mean anything from a faster query to full semantic search, and those are weeks apart in effort. can we spend 30 minutes nailing down what better actually means to the users?'" --quiet
say "ask + ambiguity + cost + small next step preserved — a clarification that shows the ambiguity's price."
