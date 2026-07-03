#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #04 — "nested: question + register polish"
#
# My lane's combo form: `?` inside `@`. A postfix `?` builds the question frame,
# then a prefix `@` polishes the wording — two ops compose to reconstruct a
# clean, well-phrased how-to question that neither op produces alone.
#
#   TARGET (41 chars):    "How do I resolve a merge conflict in Git?"
#   NLIR   (30 src chars): @('fix a git merge conflict'?)
#   REAL OUTPUT:          "How do I resolve a merge conflict in Git?"   (exact)
#
#   HOW IT NESTS:  'fix a git merge conflict'?  →  "How do I fix a git merge
#   conflict?"  (the ? question frame);  then @ lifts the register: fix→resolve,
#   "git merge conflict"→"merge conflict in Git". The seed carries only the raw
#   verb+object; the interrogative AND the polish are both generated.
#
#   CLOSENESS: exact. Distinct from target #03 (bare ?) — here @∘? adds register.
#
# Run:  ./examples/target-aur1-04-nested.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (41 chars):  How do I resolve a merge conflict in Git?"
say "NLIR (30 src chars):  @('fix a git merge conflict'?)   —  @ ∘ ?  (polish ∘ questionify)"
echo -n "  => "; "$NLIR" -e "@('fix a git merge conflict'?)" --quiet

say "Two ops compose: ? builds the question, @ polishes it — from a raw verb+object seed."
