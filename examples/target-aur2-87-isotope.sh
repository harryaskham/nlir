#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #87) — reverse game via : (simplify): CHEMISTRY jargon
# (an isotope) -> plain; : reaches for a "family" analogy and runs a little long.
#
# TARGET (~177 chars):
#   "An isotope is a version of an element that has the same number of protons but a
#    different number of neutrons -- so it's the same element chemically, just a bit
#    heavier or lighter."
#
# EXPRESSION (153 chars):
#   :'an isotope is a variant of a chemical element that has the same number of protons but a different number of neutrons giving it a different atomic mass'
#
# Real output (claude-sonnet-5):
#   "An isotope is like a family of the same element. All the members have the same
#    number of tiny particles called protons. But some of them have a few extra (or
#    fewer) particles called neutrons. That makes them weigh a little more or less, even
#    though they're still the same element."
# Closeness: same idea (same protons, different neutrons -> different mass, same element),
# plain + a family analogy (high). Runs a bit longer -- : went ELI5 on an approachable
# topic (register play).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="An isotope is a version of an element that has the same number of protons but a different number of neutrons -- so it's the same element chemically, just a bit heavier or lighter."
EXPR=":'an isotope is a variant of a chemical element that has the same number of protons but a different number of neutrons giving it a different atomic mass'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
