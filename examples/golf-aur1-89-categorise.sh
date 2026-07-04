#!/usr/bin/env bash
# nlir-golf · aur1 · #89 — "the categoriser" (#[a,b,c] names the umbrella — and refines #77)
#
# Hand `#` a LIST of things and it names the category they share: `#[a, b, c]` folds the whole
# list into its umbrella topic. A one-sigil auto-tagger for a set of items.
#
#   THE CATEGORISER   # [ a , b , c ]
#     #['apples', 'oranges', 'grapes']  → "Fruits"
#     #['redis', 'postgres', 'kafka']   → "Data infrastructure technologies"
#
# And it corrects something I found at #77. There, `>[a, b]` expanded ONLY the LAST item and
# dropped the rest. So you might expect every unary operator to grab the last of a list. It
# doesn't — and the split is meaningful. `#` FOLDS the whole list (finds the common category),
# exactly like `~[a,b,c]` folds a list into its consensus (#07). But `>` takes only the last.
#
#     REDUCTIVE ops  (# subject, ~ summary)  → FOLD the list   (combine → one category/thread)
#     GENERATIVE op  (> expand)              → take the LAST    (elaborate → can only do one)
#
# The reason is what each op is FOR: `#` and `~` COMBINE — asking "what do these share?" is a
# question about the whole set, so they read all of it. `>` GENERATES — it elaborates a single
# thing, and given several it just runs on the last. So whether a list is folded or grabbed-last
# isn't about lists at all; it's about whether the operator reduces or produces.
#
# Run:  ./examples/golf-aur1-89-categorise.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "THE CATEGORISER  #[a,b,c]  — # folds a LIST into the umbrella category they share"
echo -n "  #['apples','oranges','grapes'] => "; "$NLIR" -e "#['apples','oranges','grapes']" --quiet
echo -n "  #['redis','postgres','kafka']  => "; "$NLIR" -e "#['redis','postgres','kafka']"  --quiet

say "Refines #77: REDUCTIVE ops (# subject, ~ summary) FOLD a list; the GENERATIVE op (> expand) takes only the LAST. Combine → whole set; produce → one."
