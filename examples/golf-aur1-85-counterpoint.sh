#!/usr/bin/env bash
# nlir-golf · aur1 · #85 — "the counterpoint" (~(>@!x) : the single strongest objection, distilled)
#
# When someone proposes something and you have exactly one sentence to push back, you don't
# want a flat "no" and you don't want a five-paragraph brief — you want the ONE reason that
# matters most. `~(>@!x)` builds that: `!` flips the claim, `@` makes the opposite a serious
# stance, `>` develops the full case against it, and `~` distils that whole argument down to
# its strongest point — so what surfaces is the killer objection, not a bare negation.
#
#   THE COUNTERPOINT   ~ > @ ! x
#     claim "we should store the session tokens in localStorage so they survive page reloads"
#     !x    → "we should not store the session tokens in localStorage…"          (flat opposite)
#     ~(>@!x) → "Session tokens shouldn't be stored in localStorage due to XSS exposure risk;
#              use httpOnly cookies or in-memory storage with silent re-authentication to keep
#              sessions secure yet persistent across reloads."                    (the counterpoint)
#
# Look at the difference: `!x` just says "don't"; `~(>@!x)` says WHY (XSS) and WHAT INSTEAD
# (httpOnly / in-memory). That's because `~` isn't distilling the claim — it's distilling the
# fully-developed OPPOSITION (`>@!x`, my #65), so the one line it keeps is the argument's best
# shot. Distinct from #06's `@!x` (a diplomatic hedge, no substance) and #65's full brief:
# this is the brief boiled to its single most compelling sentence.
#
# Run:  ./examples/golf-aur1-85-counterpoint.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should store the session tokens in localStorage so they survive page reloads'

say "THE COUNTERPOINT  ~(>@!x)  — ! flip, @ stance, > develop the full case against, ~ distil to the strongest point"
echo   "  claim: $C"
echo -n "  !x     (flat opposite)    => "; "$NLIR" -e "!'$C'"    --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  ~(>@!x)  (the counterpoint) => "; "$NLIR" -e "~(>@!'$C')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "~ distils the OPPOSITION brief (#65 >@!x), so it keeps the argument's best shot — the WHY + the WHAT-INSTEAD, not a bare 'no' (vs #06 @!x)."
