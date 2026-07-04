#!/usr/bin/env bash
# nlir-golf (aur-2) — "the escalation report": expand a terse alert, then formalise.
#
#     @ ( > 'the payment page is returning errors for ~10% of users since the last deploy' )
#     └formalise┘└expand┘└──────────────── a one-line alert ────────────────┘
#
# > fleshes a terse alert into full context -- scope, likely cause, next step -- and @
# rewrites it in a formal register. A scribbled ping becomes a structured incident report
# ready to paste into a ticket. Ends on @ (formal + full): the mirror of the polished
# takeaway ~@>, which ends on ~ (formal + short).
#
# Real output (claude-sonnet-5): a full formal incident writeup (~10% of users hitting
# errors post-deploy; probable release-introduced root cause; investigate the deploy's
# changes as a priority). [run the script to see the whole report]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@>'the payment page is returning errors for about ten percent of users since the last deploy'"

echo "concept:    the escalation report -- expand a terse alert into a full formal incident writeup"
echo "expression: @>'the payment page is returning errors for about ten percent of users since the last deploy'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
