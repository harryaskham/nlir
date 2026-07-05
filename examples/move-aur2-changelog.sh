#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the changelog": turn terse dev notes into polished user-facing release
# notes — one clean line per item, in the register you choose. For changelogs, release notes, "what's
# new" emails, standup recaps.
#
# THE MOVE (reusable):
#     : [ 'ITEM_1' , 'ITEM_2' , 'ITEM_3' ]
#     └ : maps over each item (reliably; NO &) -> one polished line per item
#
# THE KEY DISTINCTION (aur-0 precised this): the & is the STRUCTURAL weave — :&['a','b','c'] always
# fuses to one sentence. WITHOUT &, the op applies to the list-rendered-as-text (in DET mode,
# !['a','b','c'] = "not a\nb\nc" — "not " is prepended ONCE, not per item), and in LLM mode the model
# TENDS to rewrite that multi-line text line-by-line, so you usually get one clean line per item — but
# that's a model tendency, NOT a structural guarantee (a long/ambiguous list could merge or renumber).
# In practice, for release notes with : simplify, it's reliable and reads great:
#   :['a','b','c']   -> a plain line per item   (a changelog; LLM per-line tendency)
#   :&['a','b','c']  -> one flowing sentence     (a summary; structural weave)
# WHICH OPS MAP over a list (aur-1 verified, op-SPECIFIC): : maps RELIABLY (use it for the changelog).
# But @[list] / >[list] are NON-DETERMINISTIC over a list (may transform only the last item, or weave),
# and reductive ~[list] / #[list] / <[list] FOLD the whole list to ONE line — so they do NOT give a
# formal / terse changelog. For a reliable per-item changelog stay on : ; use & to weave; a GUARANTEED
# per-item map for any op would need the proposed structural MAP operator, ↦.
#
# Filled example:
#   :['fixed a crash on large uploads', 'sped up search 3x', 'added keyboard shortcuts']
#
# Real output (claude-sonnet-5), one plain line per item:
#   "Fixed a problem that made big file uploads stop working"
#   "Made searching much, much faster"
#   "Added shortcut keys you can press on the keyboard"
#
# REUSE IT:  :['<note>', '<note>', '<note>']   (: is the reliable per-item mapper; add & to weave to prose)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR=":['fixed a crash on large uploads','sped up search 3x','added keyboard shortcuts']"

echo "move:       the changelog -- :['ITEM_1', 'ITEM_2', ...]  (maps the tone over each -> one line per item)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
