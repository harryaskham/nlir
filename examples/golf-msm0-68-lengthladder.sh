#!/usr/bin/env bash
# nlir-golf · msm0 · #68 — "the length ladder" (one thought, dialed shorter or longer)
#
# The sibling of #66's register ladder, on the LENGTH axis. Same ladder mechanism, a different
# basis axis (#30): one thought at three lengths, terse to detailed.
#
#   x="…" ; t=<$x ; d=>$x ; _sep="\n" ; ["terse:  $t","as-is:  $x","detail: $d"]
#   │       │       │                    └ a labelled, line-broken list
#   │       │       └ d = >$x   expand   -> the full detailed explanation
#   │       └ t = <$x   shorten  -> one crisp line
#   └────── x   the thought
#
# On "the deploy failed because a long-running query held a lock on the users table during the
# migration":
#   terse:  one crisp line
#   as-is:  the raw sentence
#   detail: a full paragraph tracing the lock contention end to end (~10× longer)
#
# Where #66 laddered the REGISTER axis (: / raw / @), this ladders the LENGTH axis (< / raw / >).
# Two of the basis axes, each read as a graded ladder — dial your message shorter or longer with a
# single operator. The length axis has the widest dynamic range of the lot: > can expand tenfold.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE LENGTH LADDER   x="…" ; t=<$x ; d=>$x ; _sep="\n" ; ["terse:  $t","as-is:  $x","detail: $d"]'
"$NLIR" --config "$CFG" --mode llm -e 'x="the deploy failed because a long-running query held a lock on the users table during the migration";t=<$x;d=>$x;_sep="\n";["terse:  $t","as-is:  $x","detail: $d"]' --quiet
say "the LENGTH axis as a ladder (< / raw / >), the sibling of #66's REGISTER ladder — dial it shorter or longer."
