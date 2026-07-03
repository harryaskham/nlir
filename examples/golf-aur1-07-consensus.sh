#!/usr/bin/env bash
# nlir-golf · aur1 · #07 — "consensus from the crowd"
#
# Fresh angle: hand nlir a LIST of competing opinions and summarise it — the
# summary of a debate is the CONSENSUS, the position the room is converging on.
# A list renders to its `_sep`-joined elements, so `~[...]` feeds every opinion
# to one summariser at once; it weighs them and reports where they land.
#
#   CONSENSUS   ~[o1,o2,o3]     (summarise a list of stances)
#     [o1,o2,o3]  the raw opinions, spread as one block
#     ~           distil them into the shared/emergent position
#
# Give it "rewrite in Rust for safety" / "Rust is too risky, stay on Go" /
# "rewrite just the hot path" and it lands on the hybrid — the compromise nobody
# stated outright but everyone was circling. A vote-counter for language, not
# numbers: N takes in, one settled line out.
#
# Run:  ./examples/golf-aur1-07-consensus.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "CONSENSUS  ~[o1,o2,o3]  — summarise a list of competing opinions = the emergent position"
echo "  o1: rewrite the service in Rust for memory safety"
echo "  o2: Rust is too risky, stay on Go"
echo "  o3: rewrite just the hot path in Rust, keep the rest in Go"
echo -n "  consensus => "
"$NLIR" -e "~['we should rewrite the service in rust for memory safety','rust is too risky, we should stay on go','maybe rewrite just the hot path in rust and keep the rest in go']" --quiet

say "N opinions in, one settled line out — a vote-counter for language, not numbers."
