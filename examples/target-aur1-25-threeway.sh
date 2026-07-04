#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #25 — "the three-way decision" (should-you, N options)
#
# The pick-one-of-several turn. A "use X or Y or Z" seed steers `?` to the
# "Should you use X, Y, or Z?" decision frame — scaling my #08 two-option should-I
# up to three, with the serial comma inserted.
#
#   TARGET (52 chars):    "Should you use Redis, Memcached, or Hazelcast for caching?"
#   NLIR   (47 src chars): 'use redis memcached or hazelcast for caching'?
#   REAL OUTPUT:          "Should you use Redis, Memcached, or Hazelcast for caching?"  (exact, stable)
#
#   CLOSENESS: exact and stable across runs. `?` capitalises each option, inserts
#   the Oxford comma, and picks the "Should you use …?" deliberation frame — a
#   three-alternative decision from bare option names. Distinct from #15's
#   two-option "Is it X or Y?" (identification): here a leading verb "use" makes it
#   a CHOICE, not an id.
#
# Run:  ./examples/target-aur1-25-threeway.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (52 chars):  Should you use Redis, Memcached, or Hazelcast for caching?"
say "NLIR (47 src chars):  'use redis memcached or hazelcast for caching'?"
echo -n "  => "; "$NLIR" -e "'use redis memcached or hazelcast for caching'?" --quiet

say "Three options + leading 'use' → a Should-you decision (vs #15's 'Is it X or Y?' id). ? scales."
