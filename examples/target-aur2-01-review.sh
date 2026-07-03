#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #01) — the REVERSE game: regenerate a target chat
# sentence from the SHORTEST nlir expression. Winner = closest match, fewest chars.
#
# TARGET (76 chars) — a typical polite pi chat request:
#   "I would appreciate it if you could review my code and provide some feedback."
#
# EXPRESSION (35 chars) — a terse seed rendered fluent by @ (formalize):
#   @'review my code and give feedback'
#
# 35 chars regenerate a 76-char courteous request — 54% compression. @ (formalize)
# is a natural DECOMPRESSOR: it inflates a blunt seed into a polite sentence.
# This is exactly the shorthand -> fluent-message workflow we'll use in pi.
#
# Real output (claude-sonnet-5):
#   Please review my code and provide your feedback.
# Closeness: same request + polite register, near-synonym phrasing (high).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="I would appreciate it if you could review my code and provide some feedback."
EXPR="@'review my code and give feedback'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
