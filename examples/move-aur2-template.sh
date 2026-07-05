#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the templated message": bind a value ONCE, reuse it across a whole message.
# Change it in one place and every mention updates. Parameterized comms / a reusable template.
#
# THE MOVE (reusable):
#     NAME='VALUE' ; @&[ "... $NAME ...", "... $NAME ...", ... ]
#     └ bind once   └ reference $NAME in DOUBLE-quoted slots; the composer weaves + fills it in
#
# You write a message that names the same thing several times (a service, a person, a date, a feature).
# Bind it once as NAME='value', then use "$NAME" wherever it appears. Swap the value in ONE spot and the
# whole message re-renders consistently — no find-and-replace, no drift.
#
# THE ONE RULE: interpolation needs DOUBLE quotes. "$NAME" fills in the value; '$NAME' stays literal.
#
# Filled example:
#   svc='the auth service';
#   @&["$svc moves to us-east this friday",
#      "expect a ten-minute maintenance window for $svc",
#      "roll back $svc if error rates exceed two percent"]
#
# Real output (claude-sonnet-5):
#   "The authentication service will be migrated to US-East this Friday. A ten-minute maintenance window
#    should be expected, and the service will be rolled back if error rates exceed two percent."
#
# REUSE IT:  NAME='<value>'; @&["...$NAME...", "...$NAME..."]   (change NAME once, the message updates)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="svc='the auth service';@&[\"\$svc moves to us-east this friday\",\"expect a ten-minute maintenance window for \$svc\",\"roll back \$svc if error rates exceed two percent\"]"

echo "move:       the templated message -- NAME='VALUE'; @&[\"...\$NAME...\", ...]  (bind once, reuse everywhere)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
