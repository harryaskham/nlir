#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #42) — reverse game via ~> (summary of expand): a dense
# technical one-liner defining a software pattern from a 32-char seed.
#
# TARGET (~186 chars):
#   "Dependency injection is a design pattern where an object is handed the other
#    objects it needs from outside, instead of creating them itself, which makes
#    code easier to test and swap out."
#
# EXPRESSION (32 chars):
#   ~>'what is dependency injection'
#
# Real output (claude-sonnet-5):
#   "Dependency injection is a design pattern where components receive their
#    dependencies from an external source rather than creating them internally,
#    promoting loose coupling, testability, and modularity, and can be implemented
#    manually or via frameworks like Spring, Angular, or .NET."
# Closeness: same core (get dependencies from outside -> testable/decoupled), but
# ~> lands the TECHNICAL register (loose coupling/modularity/frameworks) (high).
# 83% shorter. (For a plainer phrasing, use :~>.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Dependency injection is a design pattern where an object is handed the other objects it needs from outside, instead of creating them itself, which makes code easier to test and swap out."
EXPR="~>'what is dependency injection'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
