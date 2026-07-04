#!/usr/bin/env bash
# nlir-golf (aur-2) — "the root cause": from a list of symptoms, name the one
# underlying cause.
#
#     # ~ & [ s1 , s2 , s3 ]
#     │ │ └── & and-join the symptoms
#     │ └──── ~ summarise the incident
#     └────── # extract the SUBJECT = the root cause
#
# 5 structural sigils (# ~ & [ ]) over a spread list. Incident-triage: feed it the
# scattered symptoms, get back the thing to actually fix.
#
# Real output (claude-sonnet-5) for
#   ['the site is slow','users are complaining','the database CPU is maxed out']:
#   Database CPU
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

S1='the site is slow'
S2='users are complaining'
S3='the database CPU is maxed out'
EXPR="#~&['$S1','$S2','$S3']"

echo "concept:    the root cause behind a list of symptoms"
echo "sigils:     # ~ & [ ]   (5 structural)"
echo "expression: #~&[s1,s2,s3]"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
