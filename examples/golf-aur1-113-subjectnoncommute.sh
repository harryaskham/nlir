#!/usr/bin/env bash
# nlir-golf · aur1 · #113 — "the subject non-commutativity" (#>x ≠ >#x : reduce vs produce, last op wins)
#
# Two of my cards, `#>x` and `>#x`, are the same two operators in opposite order — and they land
# at opposite ends of the universe. `#` collapses a claim to its bare SUBJECT (a reduce); `>`
# blooms it into detail (a produce). Put them together and the LAST one wins, completely.
#
#   SUBJECT NON-COMMUTATIVITY     x = "we should adopt a service mesh for inter-service comms"
#     #>x  (# LAST) → "Service mesh"                                    ← collapses to the TOPIC
#     >#x  (> LAST) → "By decoupling communication logic from application code, a service mesh
#                      provides centralized control over traffic — routing, load balancing,
#                      circuit breaking…"                               ← blooms to a DEFINITION
#
# `#>x` first expands, but then `#` throws all that detail away and keeps only the subject (my
# #64: the topic survives expansion, so # absorbs the >). `>#x` first collapses to the subject,
# then `>` expands THAT into a full definition (my #82 define-topic). Two words apart in code,
# a tag vs an essay in output. This is the same "last op wins" law I found for length (`~(>x) ≠
# >~x`, #104) — but generalised: it holds for ANY reduce-vs-produce pair, not just compress-vs-
# expand. Whenever a REDUCTIVE op (#, ~, <) meets a GENERATIVE op (>), the one you apply LAST
# decides whether you end up with a label or a document.
#
# Run:  ./examples/golf-aur1-113-subjectnoncommute.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt a service mesh for inter-service communication'

say "SUBJECT NON-COMMUTATIVITY  #>x ≠ >#x  — # (reduce to subject) vs > (produce detail); the LAST op wins"
echo   "  x: $C"
echo -n "  #>x (# LAST → the TOPIC)      => "; "$NLIR" -e "#>'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >#x (> LAST → the DEFINITION) => "; "$NLIR" -e ">#'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "#>x collapses to the topic (# absorbs >, #64); >#x blooms to a definition (#82). Same 'last op wins' law as #104 (~(>x)≠>~x), GENERALISED: any REDUCTIVE op (#,~,<) vs GENERATIVE (>) — last one decides label vs document."
