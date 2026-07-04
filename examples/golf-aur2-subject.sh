#!/usr/bin/env bash
# nlir-golf (aur-2) — "the subject line": #~ turns a rambling email into a subject.
#
#     # ( ~ 'Hey team, the office will be closed this Friday ...' )
#     └subject┘└──── summary of the body ────┘
#
# ~ boils the email down to its gist; # names the SUBJECT of that gist as a short
# noun phrase -- exactly an email subject line. A wall of text in, a header out.
#
# Real output (claude-sonnet-5): Office holiday closure
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

BODY='Hey team, the office will be closed this Friday for the holiday, so please make sure any urgent deploys go out by Thursday afternoon and set your status accordingly.'

echo "concept:    #~ (subject of the summary) turns an email body into a subject line"
echo "expression: #~'<email body>'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "#~'$BODY'"
