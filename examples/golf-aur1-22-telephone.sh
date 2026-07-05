#!/usr/bin/env bash
# nlir-golf · aur1 · #22 — "the semantic telephone" (round-trip fidelity)
#
# Compress, decompress, compress again — and see what survives. `~(>~x)` summarises
# a fact, expands the summary back into prose, then re-summarises. It's the game
# of telephone in three sigils: the CORE facts pass through intact, but the middle
# expand stage can quietly embellish — a live probe of what nlir treats as
# essential vs. disposable vs. invented.
#
#   TELEPHONE   ~(>~x)     (summarise ∘ expand ∘ summarise)
#     ~x    distil to the gist
#     >~x   re-inflate the gist into a paragraph (fills gaps with plausible detail)
#     ~(>~x)  distil again → what remains after a full compress/decompress cycle
#
# "cache cut p99 from 800ms to 120ms, read-only, writes unchanged" round-trips to
# "cut read-endpoint p99 from ~800ms to ~120ms (a ~7x improvement), no change to
# writes" — the numbers and scope survive, and the expand stage even DERIVED the
# 7x. The bits that drift are the bits the model considers reconstructible.
#
# Run:  ./examples/golf-aur1-22-telephone.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
X='The new cache reduced p99 API latency from 800ms to 120ms, but only for read-heavy endpoints; writes are unchanged.'

say "TELEPHONE  ~(>~x)  — summarise, expand, re-summarise: what survives the round trip"
echo "  original: $X"
echo -n "  ~x   (gist)          => "; "$NLIR" -e "~'$X'" --quiet
echo -n "  ~(>~x) (round-tripped) => "; "$NLIR" -e "~(>~'$X')" --quiet

say "The numbers + scope survive; the expand stage may DERIVE detail (here ~7x). A fidelity probe."
