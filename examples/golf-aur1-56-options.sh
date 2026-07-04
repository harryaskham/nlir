#!/usr/bin/env bash
# nlir-golf · aur1 · #56 — "options → decision" (a list of choices becomes the question)
#
# You've brainstormed the options; now pose the call. `[a, b, c]?` takes a LIST of
# candidate actions and turns the set into the decision question — the `?` reaches into
# the list and enumerates the choices. The exact shape floats run-to-run: usually the
# combined "Should we A, B, or C?", sometimes a per-option checklist (one yes/no each).
# Either way, a jotted list of options becomes the sentence you'd put to the room.
#
#   OPTIONS → DECISION   [ a , b , c ] ?
#     options: "ship it now" · "wait for the full test suite" · "ship behind a feature flag"
#     combined  → "Should we ship it now, wait for the full test suite, or ship behind a
#                  feature flag?"                                       (the usual shape)
#     checklist → "Should we ship it now?" / "Should we wait…?" / "Should we…flag?"
#                                                                       (the per-option variant)
#
# The mechanism is the list analog of my #47 assumption-checker (`?` over a `&`): pointed
# at a collection, `?` distributes into the choice. But #47 turned FACTS into verification
# checks; this turns OPTIONS into the decision. Distinct from #15 disambig (`|∘?`, an
# either/or of two): here the input is an actual bulleted list you can grow to any length.
#
# Run:  ./examples/golf-aur1-56-options.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
L="['ship it now','wait for the full test suite','ship behind a feature flag']"

say "OPTIONS → DECISION  [a,b,c]?  — a LIST of options becomes the decision question (combined, or per-option)"
echo   "  options: ship it now · wait for the full test suite · ship behind a feature flag"
echo    "  [a,b,c]? (the vote) =>"; "$NLIR" -e "${L}?" --quiet | sed 's/^/     • /'

say "? reaches into a LIST and enumerates the choice — the list analog of #47's ?-over-& (facts vs options)."
