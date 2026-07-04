#!/usr/bin/env bash
# nlir-golf · aur1 · #46 — "the brief builder" (stack terse bullets → a written brief)
#
# The complement of my #17 accumulator, and the other thing a premise-stack is good
# for. Push a few terse bullet points, fold them together with `&`, then EXPAND the
# whole with `>$` — and nlir turns the jotted list into flowing, connected prose: a
# written brief. Where #17 folded-then-SUMMARISED (bullets → the gist), this
# folds-then-EXPANDS (bullets → the write-up).
#
#   BRIEF BUILDER   p1 ; p2 ; p3 ; & ; >$
#     bullets: "no rate limiting" · "traffic tripled last month" · "a scraping incident"
#     &   → "…no rate limiting AND traffic tripled AND we hit a scraping incident"  (joined)
#     >$  → "The public-facing API currently has no rate limiting, meaning no mechanism
#            restricts how many requests a client can make… This leaves the API exposed,
#            and with traffic having tripled and a scraping incident already observed…"
#           (the bullets, woven into a coherent written brief)
#
# So one premise-stack, two exits: `~$` compresses it to the point (#17), `>$` inflates
# it to prose (this one). Jot the facts as you gather them, then choose your altitude —
# the TL;DR or the full write-up. The "turn my notes into paragraphs" button.
#
# Run:  ./examples/golf-aur1-46-briefbuilder.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
P="'the public API has no rate limiting';'traffic tripled last month';'we hit a scraping incident'"

say "BRIEF BUILDER  p1;p2;p3;&;>\$  — stack terse bullets, fold, and EXPAND into a written brief"
echo -n "  p1;p2;p3;&    (joined bullets) => "; "$NLIR" -e "${P};&" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo    "  p1;p2;p3;&;>\$ (the brief)     =>"; "$NLIR" -e "${P};&;>\$" --quiet | fold -s -w 86 | sed 's/^/     /'

say "One premise-stack, two exits: ~\$ compresses to the point (#17), >\$ inflates to prose (this). Notes → paragraphs."
