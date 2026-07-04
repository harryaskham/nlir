#!/usr/bin/env bash
# nlir-golf · aur1 · #104 — "the length non-commutativity" (~>x ≠ >~x : the last op wins the length axis)
#
# Two of my oldest cards are actually the SAME two operators in opposite order — and they land
# in completely different places. `~>x` (my #22 telephone) and `>~x` (my #55 deep-dive) both use
# expand `>` and compress `~`; only the ORDER differs, and the order decides everything.
#
#   LENGTH NON-COMMUTATIVITY   ~>x  ≠  >~x
#     x = "our onboarding loses 40% of users at the email verification step, hurting growth"
#     ~>x (compress LAST) → "Email verification causes a 40% drop-off during onboarding — a
#          bottleneck that wastes acquisition spend and hampers growth."      ← SHORT (essence)
#     >~x (expand LAST)   → "During onboarding, a substantial share — roughly 40% — abandon the
#          sign-up flow specifically at email verification, meaning they either never open the
#          confirmation email or…"                                            ← LONG (a treatment)
#
# Why: `>` and `~` are OPPOSED operations on the SAME axis (length) — one lengthens, one
# shortens. When two ops fight over the same axis, they don't commute, and the one you apply
# LAST wins: `~>x` ends on `~`, so it's short (expand-then-distil round-trips back to the point
# — the telephone game); `>~x` ends on `>`, so it's long (distil-then-expand builds a focused
# essay on the core). This is the length-axis twin of my #26 register non-commutativity
# (`@:x ≠ :@x`): opposed same-axis ops are order-sensitive, and the last move dominates.
# (Contrast the COMMUTING pairs — #75 `@>≈>@` and #98 `@<≈<@` — where the axes are DIFFERENT.)
#
# Run:  ./examples/golf-aur1-104-lengthnoncommute.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='our onboarding flow loses forty percent of users at the email verification step which is hurting growth'

say "LENGTH NON-COMMUTATIVITY  ~>x ≠ >~x  — opposed ops on the SAME axis; the LAST one wins"
echo   "  x: $C"
echo -n "  ~>x (compress LAST → SHORT, #22 telephone) => "; "$NLIR" -e "~>'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >~x (expand LAST → LONG, #55 deep-dive)    => "; "$NLIR" -e ">~'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "> and ~ fight over the LENGTH axis, so order matters: the last op wins (~ last → short, > last → long). The length-axis twin of #26 @:x≠:@x. (Commuting pairs #75 @>≈>@ / #98 @<≈<@ use DIFFERENT axes.)"
