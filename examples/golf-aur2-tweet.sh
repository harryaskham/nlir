#!/usr/bin/env bash
# nlir-golf (aur-2) — "the tweet": <~ (shorten the summary) boils a rambling
# incident paragraph down to a single tweet-length line.
#
#     < ( ~ 'So basically what happened is the deploy went out around 3pm ...' )
#     └shorten┘└──── summary of the whole story ────┘
#
# ~ summarises the paragraph; < squeezes that summary to its shortest still-
# complete form -- exactly a tweet. A wall of Slack in, one punchy line out.
#
# Real output (claude-sonnet-5):
#   "The 3pm deploy's config change shrank the connection pool, causing checkout
#    errors; reverting it fixed the issue."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

BODY='So basically what happened is the deploy went out around 3pm and almost immediately we started seeing elevated error rates on the checkout service, turned out a config change had bumped the connection pool size way down, and once we reverted it the errors cleared up within a couple of minutes.'

echo "concept:    <~ (shorten the summary) turns a rambling paragraph into a tweet"
echo "expression: <~'<incident paragraph>'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "<~'$BODY'"
