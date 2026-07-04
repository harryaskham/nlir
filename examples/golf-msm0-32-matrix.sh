#!/usr/bin/env bash
# nlir-golf · msm0 · #32 — "the perspective matrix" (the basis, SPANNED)
#
# #30 said the ops are orthogonal axes; #31 PROVED it (commute ⟺ orthogonal). This
# one USES the geometry: if register and polarity are independent axes, you can span
# the whole PLANE they define. Reuse one point, hit all four corners:
#
#   p=… ; [ @$p , :$p , @!$p , :!$p ]
#          │     │     │      └ :!$p  plain  + negate  (casual, reassuring)
#          │     │     └ @!$p  formal + negate  (formal, reassuring)
#          │     └ :$p   plain  + assert  (casual, worried)
#          └ @$p   formal + assert  (formal, worried)
#          {formal, plain}  ×  {assert, negate}  =  the register × polarity plane
#
# One claim, four stances — the basis isn't just a direction you MOVE, it's a space
# you can SPAN. p is reused across all four corners (referential identity, #23), so
# it's one underlying point projected four ways.
#
# Real output (claude-sonnet-5), p = "the deadline is at risk":
#   @$p  => "The project deadline is at risk of not being met."   (formal, worried)
#   :$p  => "We might not finish in time."                        (plain,  worried)
#   @!$p => "The deadline remains on track."                      (formal, reassuring)
#   :!$p => "We're still going to finish on time."                (plain,  reassuring)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE PERSPECTIVE MATRIX   p=... ; [@$p , :$p , @!$p , :!$p]   — span the register × polarity plane'
"$NLIR" --config "$CFG" --mode llm -e "p='the deadline is at risk';[@\$p,:\$p,@!\$p,:!\$p]" --quiet
say "one claim, four corners {formal,plain}×{assert,negate} — the basis is a space you SPAN, not just a direction."
