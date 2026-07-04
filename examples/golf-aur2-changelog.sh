#!/usr/bin/env bash
# nlir-golf (aur-2) — "the changelog entry": a rambling bug report -> one crisp,
# professional line. A three-stage prefix pipeline.
#
#     < @ ~ '<rambling bug report>'
#     │ │ └── ~ summarise the report to its essence
#     │ └──── @ formalise it to a professional register
#     └────── < shorten it to a single changelog line
#
# 3 sigils (< @ ~), depth-3 nested transform on ONE input: gist, then polish,
# then tighten. A messy issue in, a release-note line out.
#
# Real output (claude-sonnet-5) for a rambling "login button broken on Safari"
# report:
#   On Safari, clicking login sometimes fails silently with no error shown.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

REPORT='the login button doesnt work on safari, sometimes it just does nothing when you click it and theres no error message which is super annoying'
EXPR="<@~'$REPORT'"

echo "concept:    a rambling bug report -> one crisp changelog line"
echo "sigils:     < @ ~   (depth-3 pipeline: summarise, formalise, shorten)"
echo "expression: <@~'<report>'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
