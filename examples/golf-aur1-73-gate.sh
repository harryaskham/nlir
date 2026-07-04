#!/usr/bin/env bash
# nlir-golf · aur1 · #73 — "the readiness gate" (a task list → ONE go/no-go question)
#
# Point `?` at a list of tasks and it gives you a single go/no-go: `[t1, t2, t3]?` becomes
# one question that asks whether ALL of them are done — the gate you check before you ship.
#
#   THE READINESS GATE   [ t1 , t2 , t3 ] ?
#     ['tests written', 'docs updated', 'changelog entry added']?
#       → "Have the tests been written, the docs updated, and the changelog entry added?"
#
# And it corrected me. I expected `?` to DISTRIBUTE over the list — one question per item, a
# checklist. It doesn't: `?` over a collection makes ONE collective question about the whole
# set, not one each. That refines the whole ?-over-collection family — every member folds the
# collection into a SINGLE question, shaped by what's inside it:
#     • tasks   → "are all of these done?"      (this — the readiness gate)
#     • options → "which of these?"             (#56 options→decision)
#     • premises→ "do these assumptions hold?"  (#47 assumption-checker, via `&`)
# Same projection, one question out — because `?` collapses to the essential ask (see #72),
# and "the essential ask" about a list is a single question, not a pile of them.
#
# Run:  ./examples/golf-aur1-73-gate.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "THE READINESS GATE  [t1, t2, t3]?  — a task list → ONE go/no-go question"
echo   "  tasks: ['tests written', 'docs updated', 'changelog entry added']"
echo -n "  [...]?  => "; "$NLIR" -e "['tests written','docs updated','changelog entry added']?" --quiet | fold -s -w 80 | sed '2,$s/^/             /'

say "? over a collection makes ONE collective question (NOT per-item): tasks→gate / options→decision (#56) / premises→checks (#47)."
