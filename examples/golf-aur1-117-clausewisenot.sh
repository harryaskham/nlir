#!/usr/bin/env bash
# nlir-golf · aur1 · #117 — "not is clause-wise, not Boolean" (!(a&b) ≠ De Morgan; ! falsifies every clause)
#
# A tempting assumption: since nlir has `!` (not), `&` (and), `|` (or), maybe `!(a&b)` obeys De
# Morgan and returns the logical "not both" (¬a OR ¬b). It doesn't. `!` is a NATURAL-LANGUAGE
# negator, not a Boolean one: it makes EVERY clause false, keeping them joined — "none of this
# is true."
#
#   NOT IS CLAUSE-WISE
#     'the tests pass' & 'the build works'
#       → "the tests pass and the build works"
#     !( 'the tests pass' & 'the build works' )
#       → "the tests don't pass AND the build doesn't work"     ← ¬a ∧ ¬b  (NEITHER)
#          (Boolean De Morgan would be ¬a ∨ ¬b — "not BOTH" — nlir does NOT do this)
#     !( 'we ship today' | 'we ship tomorrow' )
#       → "we don't ship today AND we don't ship tomorrow"      ← ¬a ∧ ¬b  (NEITHER)
#
# Both the `&` group and the `|` group negate to the SAME shape: every clause falsified, joined
# with "and". So `!` doesn't compute a logical complement — it FALSIFIES CLAUSES. This is the
# same behaviour I found at #87 (`!` on an ARGUMENT flips every clause to false); here it's over
# an explicit group. The upshot, honestly stated: nlir speaks LANGUAGE, not LOGIC. Don't reach
# for De Morgan. What `!(group)` IS good for is the TOTAL opposite — "state the complete
# negation of this whole situation" (`!(a & b & c)` = "none of a, b, c holds") — a clean way to
# flip a compound claim to its full contrary.
#
# (Cosmetic: the leading "(" is the paren-echo — fix prototyped, awaiting green-light.)
#
# Run:  ./examples/golf-aur1-117-clausewisenot.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "NOT IS CLAUSE-WISE, NOT BOOLEAN  — !(a&b) makes EVERY clause false (¬a ∧ ¬b), NOT De Morgan's ¬a ∨ ¬b"
echo -n "  a & b        => "; "$NLIR" -e "'the tests pass' & 'the build works'"    --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  !(a & b)     => "; "$NLIR" -e "!('the tests pass' & 'the build works')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo   "                 ^ ¬a ∧ ¬b (NEITHER) — Boolean would be ¬a ∨ ¬b (not BOTH). nlir does NOT do De Morgan."
echo -n "  !(a | b)     => "; "$NLIR" -e "!('we ship today' | 'we ship tomorrow')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo   "                 ^ same shape: ¬a ∧ ¬b. ! FALSIFIES every clause regardless of connective."

say "! is a clause-wise falsifier (like #87: ! on an argument flips every clause), NOT a logical complement — nlir speaks LANGUAGE not LOGIC. Good for the TOTAL opposite of a compound claim; don't expect De Morgan."
