#!/usr/bin/env bash
# nlir-golf · aur1 · #55 — "the focused deep-dive" (strip the noise, THEN elaborate)
#
# Order matters, usefully. `>~x` distils to the core FIRST (`~` drops the tangents and
# noise), and only THEN expands (`>` develops what's left). So you get a thorough,
# clean treatment of the ESSENTIAL point — not a fat elaboration of everything you
# happened to say, tangents and all, which is what a bare `>x` risks.
#
#   FOCUSED DEEP-DIVE   > ~ x
#     messy input: "we need to fix the flaky checkout test… probably a race in the
#                   payment mock, oh and the coffee machine is broken again, anyway
#                   the flaky test is blocking the release pipeline"
#     >x   → "…getting back to the main point, this flaky checkout test is blocking the
#             pipeline…"                        (expands everything — still nods at the noise)
#     >~x  → "The checkout test has become flaky — it doesn't produce consistent results
#             across repeated runs even though the code hasn't changed; on some runs…"
#             (the coffee is GONE — a clean, structured deep-dive on just the core)
#
# The `~` is a FOCUS FILTER placed before the expansion: distil, then develop. It's the
# reverse of my #22 telephone (`~>x` = expand THEN distil, drifting the meaning); here the
# distil comes first so the noise never makes it into the elaboration. Reach for `>~x`
# when a messy note has one real point buried in it and you want that point, fully written.
#
# Run:  ./examples/golf-aur1-55-deepdive.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
S='we need to fix the flaky checkout test — it fails maybe one in ten runs, probably a race in the payment mock, oh and the coffee machine is broken again, anyway the flaky test is blocking the release pipeline'

say "FOCUSED DEEP-DIVE  >~x  — distil to the core (~ drops tangents), THEN expand only what matters (>)"
echo -n "  >x  (expand ALL, noise too)   => "; "$NLIR" -e ">'$S'"  --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  >~x (focus, then deep-dive)   => "; "$NLIR" -e ">~'$S'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "~ is a focus filter BEFORE the expansion. Reverse of #22 telephone (~>x = expand then distil). Distil, then develop."
