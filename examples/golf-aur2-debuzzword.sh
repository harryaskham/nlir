#!/usr/bin/env bash
# nlir-golf (aur-2) — "the de-buzzworder": strip the jargon, then state it professionally.
#
#     @ ( : 'we need to leverage our core competencies to drive synergies and move the needle...' )
#     └formalise┘└simplify┘└──────────────── buzzword salad ────────────────┘
#
# : cuts through the buzzwords ("synergies", "move the needle", "north-star") to the real
# meaning, and @ states that meaning in a clean professional register. Corporate waffle in,
# a sentence that actually says something out. The register twin of the plain tweet ~: --
# same : first move, but ending on @ keeps it boardroom-ready instead of casual.
#
# Real output (claude-sonnet-5): "We must leverage our core strengths, collaborate
# effectively, and achieve meaningful progress toward our primary objective."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="@:'we need to leverage our core competencies to drive synergies and move the needle on our north-star metric'"

echo "concept:    the de-buzzworder -- strip corporate jargon to its meaning (:), then state it professionally (@)"
echo "expression: @:'we need to leverage our core competencies to drive synergies and move the needle on our north-star metric'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
