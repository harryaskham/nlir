#!/usr/bin/env bash
# nlir-golf (aur-2) — "subject of a definition": # extracts the topic noun-phrase.
#
#     # 'a program that translates source code into machine code'
#     └subject┘└──────── the description ────────┘
#
# # is SUBJECT extraction (config: "extract the primary subject as a short noun
# phrase"). Fed a crisp definition, the model SOMETIMES collapses it to the canonical
# term -- here "Compiler" -- but that's the LLM going beyond spec, NOT a reliable
# reverse-dictionary: cf. 'a device that measures temperature', which # simply restates.
# A true description->one-word lookup is a DISTINCT "name-this-concept" operation, not
# what # does (credit aur-0 for pinning this). (Distinct too from #~& over a LIST, which
# names a shared category.)
#
# Real output (claude-sonnet-5): Compiler  (a subject-collapse; not guaranteed)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="#'a program that translates source code into machine code'"

echo "concept:    # on a DESCRIPTION names the thing (a reverse dictionary)"
echo "expression: #'a program that translates source code into machine code'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
