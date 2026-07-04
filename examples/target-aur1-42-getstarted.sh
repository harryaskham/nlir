#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #42 — "the getting-started question" (How do I start with X?)
#
# The "how do I start with X?" turn — a beginner asking for an on-ramp, not a
# specific task. A "how do i start learning X" seed steers `?` to the "How do I
# start learning X?" onboarding frame.
#
#   TARGET (30 chars):    "How do I start learning Rust?"
#   NLIR   (30 src chars): 'how do i start learning rust'?
#   REAL OUTPUT:          "How do I start learning Rust?"   (exact)
#
#   CLOSENESS: exact (30 → 30, a wash). The 31st ? framing. `?` keeps the
#   first-person "How do I start learning …?" on-ramp frame and capitalises the
#   proper noun. Distinct from #01 "How do I …?" (a specific task) and #21 "best
#   way to …?" (idiomatic approach): this is the absolute-beginner where-do-I-begin.
#
# Run:  ./examples/target-aur1-42-getstarted.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  How do I start learning Rust?"
say "NLIR (30 src chars):  'how do i start learning rust'?"
echo -n "  => "; "$NLIR" -e "'how do i start learning rust'?" --quiet

say "31st ? framing: 'how do i start learning X' → a beginner ON-RAMP question (vs #01 task, #21 best-way)."
