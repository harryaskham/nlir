#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #97) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner from a 17-char seed (ties CDN as my tightest ~> seed).
#
# TARGET (~208 chars):
#   "OAuth is a standard that lets you grant one app limited access to your account on
#    another service -- like letting an app use your Google login -- without ever
#    sharing your actual password, using tokens instead."
#
# EXPRESSION (17 chars):
#   ~>'what is oauth'
#
# Real output (claude-sonnet-5):
#   "OAuth lets a user grant a third-party app limited, revocable access to their data
#    via temporary tokens instead of sharing their actual login credentials."
# Closeness: same core (grant a third-party app limited access via tokens, NOT by
# sharing your password), high; ~> lands a tight textbook line (+ "revocable"). 92%
# shorter -- 17 chars into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="OAuth is a standard that lets you grant one app limited access to your account on another service -- like letting an app use your Google login -- without ever sharing your actual password, using tokens instead."
EXPR="~>'what is oauth'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
