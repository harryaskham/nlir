#!/usr/bin/env bash
# nlir-golf · aur1 · #48 — "the polish" (a rough half-idea → its strongest form)
#
# The make-my-mumble-its-best-self button. `>@x` takes a half-formed, hedged, thinking-
# out-loud note and returns a fully-articulated, professional proposal: `@` lifts the
# register and drops the "idk", `>` fills in the substance and the reasoning. You supply
# the SPARK; nlir supplies the polish and the depth.
#
#   THE POLISH   > @ x        (formalise, then expand)
#     rough  "maybe we could cache stuff so the app feels snappier idk"
#     @x   → "Consider implementing caching to improve the application's responsiveness."
#            (register lifted, hedge removed — the crisp one-liner)
#     >@x  → "Consider implementing a caching mechanism to improve responsiveness. Caching
#            temporarily stores frequently accessed or expensive data — query results, API
#            responses, rendered content — in a fast-access layer, so repeat requests are
#            served without recomputation…"                        (the full proposal)
#
# This runs the register×length plane in the OPPOSITE direction from my #32 exec-summary
# (`@~x` = formal + BRIEF, compressing a doc down): here `>@x` = formal + LONG, inflating a
# scrap UP into a document. Same two axes, reverse gear — from a sticky-note to a spec.
#
# Run:  ./examples/golf-aur1-48-polish.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='maybe we could cache stuff so the app feels snappier idk'

say "THE POLISH  >@x  — a rough, hedged half-idea lifted into a full, formal proposal"
echo   "  rough: $C"
echo -n "  @x  (crisp one-liner) => "; "$NLIR" -e "@'$C'" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo    "  >@x (the full proposal) =>"; "$NLIR" -e ">@'$C'" --quiet | fold -s -w 86 | sed 's/^/     /'

say ">@x runs #32's register×length plane in REVERSE: exec-summary compresses a doc; the polish inflates a scrap."
