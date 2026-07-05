#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the changelog": turn terse dev notes into polished user-facing release
# notes — one clean line per item, in the register you choose. For changelogs, release notes, "what's
# new" emails, standup recaps.
#
# THE MOVE (reusable):
#     : [ 'ITEM_1' , 'ITEM_2' , 'ITEM_3' ]
#     └ the tone op MAPS over each item (NO &) -> one polished line per item
#
# THE KEY DISTINCTION (learned here): a leading op on a list WITHOUT & MAPS over the items — you get
# one rewritten line PER item. Add & and it WEAVES them into a single sentence instead:
#   :['a','b','c']   -> three separate plain lines   (a changelog)
#   :&['a','b','c']  -> one flowing sentence          (a summary)
# The & is the weave. So for a bulleted list, drop the & and just pick the register:
#   : = friendly release notes · @ = formal changelog · ~ = terse one-liners
#
# Filled example:
#   :['fixed a crash on large uploads', 'sped up search 3x', 'added keyboard shortcuts']
#
# Real output (claude-sonnet-5), one plain line per item:
#   "Fixed a problem that made big file uploads stop working"
#   "Made searching much, much faster"
#   "Added shortcut keys you can press on the keyboard"
#
# REUSE IT:  :['<note>', '<note>', '<note>']   (swap : for @ = formal, ~ = terse; add & to weave to prose)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR=":['fixed a crash on large uploads','sped up search 3x','added keyboard shortcuts']"

echo "move:       the changelog -- :['ITEM_1', 'ITEM_2', ...]  (maps the tone over each -> one line per item)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
