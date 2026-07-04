#!/usr/bin/env bash
# nlir-golf · aur1 · #24 — "the three-way zoom"
#
# One document, three altitudes, from a single push. Drop a doc on the stack and
# read it back through three operators at different zoom levels: the tag (zoom
# out), the summary (cruising altitude), and the full elaboration (zoom in). The
# source is peeked three times, so it appears ONCE — an index-entry, an abstract,
# and a deep-dive in one expression.
#
#   ZOOM   '<doc>' ; [#$ , ~$ , >$]
#     #$   subject → the 1-3 word TAG (a filing label / heading)
#     ~$   summary → the one-line ABSTRACT
#     >$   expand  → the full ELABORATION (the explainer)
#
# A circuit-breaker paragraph becomes: "Circuit breaker" / "fails fast after 5
# failures by opening for 30s, then half-opens to test recovery" / a full
# paragraph on open→half-open→closed states. Zoom out for the wiki title, stay
# for the TL;DR, zoom in for the docs — same source, three depths.
#
# Run:  ./examples/golf-aur1-24-zoom.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
D='The circuit breaker wraps calls to the payments provider; after 5 consecutive failures it opens for 30 seconds, short-circuiting requests to fail fast, then half-opens to test recovery before closing again.'

say "THREE-WAY ZOOM  '<doc>';[#\$,~\$,>\$]  — TAG | ABSTRACT | ELABORATION, one push, peeked 3x"
echo -n "  #\$ (tag)      => "; "$NLIR" -e "'$D';#\$" --quiet
echo -n "  ~\$ (abstract) => "; "$NLIR" -e "'$D';~\$" --quiet
echo   "  >\$ (elaboration) =>"; "$NLIR" -e "'$D';>\$" --quiet | fold -s -w 88 | sed 's/^/     /'

say "Zoom out for the title (#), stay for the TL;DR (~), zoom in for the docs (>) — one source."
