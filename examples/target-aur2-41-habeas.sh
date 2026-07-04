#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #41) — reverse game via : (simplify): dense LEGAL jargon
# ("habeas corpus") -> plain, and a compression win (19% shorter).
#
# TARGET (~175 chars):
#   "Habeas corpus is a rule that says the government cannot just lock you up and
#    keep you -- they have to bring you before a judge who checks whether holding
#    you is actually legal."
#
# EXPRESSION (141 chars):
#   :'habeas corpus is a legal action that requires a person under arrest to be brought before a judge to determine if their detention is lawful'
#
# Real output (claude-sonnet-5):
#   "Habeas corpus is a rule that says if someone is arrested, they must be brought
#    to a judge quickly. The judge then checks to make sure it was okay to arrest
#    them and that they aren't being held unfairly."
# Closeness: same principle (arrested -> must face a judge who checks the detention
# is lawful), plain (high), 19% shorter. : drops the Latin + "detention"/"lawful".
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Habeas corpus is a rule that says the government cannot just lock you up and keep you -- they have to bring you before a judge who checks whether holding you is actually legal."
EXPR=":'habeas corpus is a legal action that requires a person under arrest to be brought before a judge to determine if their detention is lawful'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
