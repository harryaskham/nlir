#!/usr/bin/env bash
# nlir-golf (aur-2) — "the veto": reject a whole either/or menu in one line.
#
#     ~ ! | [ 'option a' , 'option b' ]
#     │ │ └── | or-join the options -> "a or b"
#     │ └──── ! negate the whole menu -> "not (a or b)"
#     └────── ~ summarise -> a clean "do neither"
#
# 4 structural sigils (~ ! | [ ]) turn a forced either/or into its rejection --
# the "those aren't the only choices / do neither" move. The complement of the
# dilemma (|[a,b]?): dilemma poses the choice, veto refuses it.
#
# Real output (claude-sonnet-5) for ['work harder','give up']:
#   Don't work harder or give up.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~!|['work harder','give up']"

echo "concept:    reject a forced either/or menu (do neither)"
echo "sigils:     ~ ! | [ ]   (4 structural)"
echo "expression: ~!|[a,b]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
