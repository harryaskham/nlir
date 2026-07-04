#!/usr/bin/env bash
# nlir-golf (aur-2) — "the one-line rebuttal": negate, expand, distil = a punchy counter.
#
#     ~ ( > ( ! 'we should rewrite the whole codebase in rust' ) )
#     └distil┘└expand┘└negate┘└──────────── the claim ────────────┘
#
# ! flips the claim to its opposite, > builds the full case against it, ~ boils that case
# down to a single punchy line. The concise cousin of the full steelman >!x: same three
# ideas, but ending on ~ gives you a one-sentence counter-thesis instead of an essay --
# a quick devil's advocate you can drop into a thread.
#
# Real output (claude-sonnet-5): "A full Rust rewrite is too risky and costly right now;
# incremental adoption in high-value areas is safer than a wholesale rewrite."
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~>!'we should rewrite the whole codebase in rust'"

echo "concept:    the one-line rebuttal -- distil the expanded negation into a punchy counter-thesis"
echo "expression: ~>!'we should rewrite the whole codebase in rust'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
