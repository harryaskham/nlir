#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #84 — "the redundancy question" (Am I reinventing the wheel?)
#
# The "am I reinventing the wheel?" turn — checking whether a solution you're building already
# exists, a don't-duplicate check. A first-person "am i reinventing the wheel" seed steers `?`
# to that redundancy frame.
#
#   TARGET (25 chars):    "Am I reinventing the wheel?"
#   NLIR   (27 src chars): 'am i reinventing the wheel'?
#   REAL OUTPUT:          "Am I reinventing the wheel?"   (exact)
#
#   CLOSENESS: exact. The 73rd ? framing. `?` keeps the "reinventing the wheel?" redundancy
#   idiom. Distinct from #30 is-X-overkill (too much for the need) and #79 simplest-thing
#   (the minimal build): this asks whether the thing ALREADY EXISTS and you're rebuilding it.
#
# Run:  ./examples/target-aur1-84-redundancy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (25 chars):  Am I reinventing the wheel?"
say "NLIR (27 src chars):  'am i reinventing the wheel'?"
echo -n "  => "; "$NLIR" -e "'am i reinventing the wheel'?" --quiet

say "73rd ? framing: 'am i reinventing the wheel' → does it ALREADY EXIST (vs #30 is-X-overkill, #79 simplest-thing)."
