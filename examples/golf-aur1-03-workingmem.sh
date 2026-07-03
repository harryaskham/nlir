#!/usr/bin/env bash
# nlir-golf · aur1 · #03 — "the stack as working memory"
#
# #02 showed the stack folds ($ peeks the TOP). This shows the stack as WORKING
# MEMORY: push intermediate results, then reach BACK into earlier ones by index.
#   $     = top          $-1 = top      $-2 = second-from-top      $0/$1.. = from bottom
# msm0 does value-reuse via `=`/`$name` (named); this is the complementary
# UNNAMED form — the stack itself holds your intermediates, addressable by slot.
#
#   DIALECTIC-ON-THE-STACK   'T';!$;~($-2&$)     (thesis→antithesis→synthesis as 3 slots)
#     push T (thesis) · !$ negates the top → A (antithesis), pushed ·
#     ~($-2&$) summarises slot(-2)=T AND slot(top)=A → the synthesis/tension.
#     The classic 3-part move IS three stack slots; $-2 reaches past the top.
#
#   SOURCE-KEPT DISTILL      '<long>';<$;[$-2,$]  (keep the source, add a derived view)
#     push the long text · <$ shortens the top → a TL;DR, pushed ·
#     [$-2,$] emits [ original , distilled ] — the source is still addressable at $-2.
#
# Reaching back by index ($-2) is what a register/variable would do elsewhere —
# here it's just the stack, no names.
#
# Run:  ./examples/golf-aur1-03-workingmem.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "DIALECTIC-ON-THE-STACK  'T';!\$;~(\$-2&\$)  — 3 slots = thesis, antithesis, synthesis"
echo "  thesis: a four-day work week improves employee wellbeing"
echo -n "  => "
"$NLIR" -e "'a four-day work week improves employee wellbeing';!\$;~(\$-2&\$)" --quiet

say "SOURCE-KEPT DISTILL  '<long>';<\$;[\$-2,\$]  — [ original , distilled ], source kept at \$-2"
"$NLIR" -e "'The quarterly report indicates a substantial and sustained increase in customer churn driven primarily by pricing changes';<\$;[\$-2,\$]" --quiet

say "No variables — the stack is the memory; \$-2 reaches back past the top."
