#!/usr/bin/env bash
# nlir IDIOM · aur1 · 13 — "the theme-finder"   #['a', 'b', 'c']
#
# A reusable MOVE for the pi plugin. You've got several scattered things — bug
# reports, bits of feedback, meeting notes — and you want the ONE category or
# pattern they share. `#` names the subject of a thing; over a LIST, it folds the
# whole list down to the common theme:
#
#     #[ 'item a' , 'item b' , 'item c' ]
#     │  └────────────┬────────────┘
#     │               └─ a list of scattered items
#     └───── # folds the list to the single category / theme they share
#
# This is `#`'s list behaviour: where `~` on a list finds the consensus and `<`
# tightens, `#` names the bucket. Great for triage ("what are these really
# about?") and synthesis ("what's the pattern here?").
#
# HOW TO REUSE IT (type this in chat) over any pile of items:
#     |#['reset-password broken', 'login times out', 'OAuth callback 500s']
#     |#['docs are stale', 'no changelog', 'API examples 404']
#
# Run:  ./examples/idiom-aur1-13-theme-finder.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "THE THEME-FINDER   #['a', 'b', 'c']   — several scattered items → the one category they share"
echo "  your items:  reset-password is broken · login times out on mobile · OAuth callback returns 500"
echo -n "  => "
"$NLIR" -e "#['reset-password is broken', 'login times out on mobile', 'the OAuth callback returns a 500']" --quiet | fold -s -w 82 | sed '2,$s/^/     /'
echo
echo "  another pile (product feedback):"
echo -n "  => "
"$NLIR" -e "#['the onboarding is confusing', 'I could not find the export button', 'the settings page overwhelmed me']" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "# on a list folds it to the common theme (vs ~ = consensus, < = tighten). Paste scattered issues/notes, get the bucket. Great for triage + synthesis."
