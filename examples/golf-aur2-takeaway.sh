#!/usr/bin/env bash
# nlir-golf (aur-2) — "the polished takeaway": expand, formalise, distil = an exec one-liner.
#
#     ~ ( @ ( > 'we lost three customers this week because onboarding is confusing' ) )
#     └distil┘└formalise┘└expand┘└──────────────── a casual note ────────────────┘
#
# A 3-op train: > fleshes the casual note into full context, @ rewrites it in a formal
# register, ~ boils it back to one crisp line. Scribbled thought in, board-ready takeaway
# out. Last op wins the shape (ending on ~ = one line); reorder and you get a different
# artifact (cf aur-1 #104 last-op-wins).
#
# Real output (claude-sonnet-5): Confusing onboarding caused three customers to churn this week.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~@>'we lost three customers this week because onboarding is confusing'"

echo "concept:    the polished takeaway -- expand, formalise, distil a casual note to a crisp exec line"
echo "expression: ~@>'we lost three customers this week because onboarding is confusing'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
