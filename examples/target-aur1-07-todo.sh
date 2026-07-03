#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #07 — "the to-do request" (& ∘ @ combo)
#
# A super-common pi turn: hand the assistant a LIST of tasks in one polite ask.
# My combo lane: `&` bundles the raw tasks, `@` formalises the bundle into a
# courteous multi-clause request. Two ops reconstruct a full to-do sentence from
# three terse fragments.
#
#   TARGET (94 chars):
#     "Please implement error handling, write corresponding tests, and update
#      the documentation accordingly."
#   NLIR (49 src chars):
#     @&['add error handling','write tests','update the docs']
#   REAL OUTPUT (varies run-to-run; two seen):
#     "Please implement error handling, write corresponding tests, and update
#      the documentation accordingly."
#     "Add error handling, write tests, and update the documentation."
#
#   CLOSENESS: high — both are the same three tasks in a single grammatical
#   request; register floats between polite ("Please implement…") and plain
#   imperative depending on the run. HOW IT NESTS: &[...] joins the three
#   fragments into "… and … and …"; @ then lifts the bundle to a well-formed
#   multi-clause request. The list carries only the task stems; the connective
#   grammar (and the politeness) is generated.
#
# Run:  ./examples/target-aur1-07-todo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (94 chars):  Please implement error handling, write corresponding tests, and update the documentation accordingly."
say "NLIR (49 src chars):  @&['add error handling','write tests','update the docs']   —  @ ∘ &"
echo -n "  => "; "$NLIR" -e "@&['add error handling','write tests','update the docs']" --quiet

say "& bundles the tasks, @ makes it a polite multi-clause request — a to-do list from 3 stems."
