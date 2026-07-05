#!/usr/bin/env bash
# nlir IDIOM · aur1 · 12 — "the plain-English"   ~:^-1
#
# A reusable MOVE for the pi plugin. An agent just answered in dense jargon and
# you want it in plain, accurate terms — no acronyms, no lock-mutex-singleflight,
# but not dumbed into nonsense either. One line, reading the agent's message:
#
#     ~ : ^-1
#     │ │  │
#     │ │  └─ ^-1  the agent's last (jargon-heavy) message
#     │ └──── :   simplify the register — strip the jargon to plain language
#     └────── ~   distil to a crisp sentence
#
# ORDER MATTERS (nlir operators don't commute): `~:^-1` simplifies THEN distils,
# giving a crisp professional plain-English line; `:~^-1` distils THEN simplifies,
# which over-simplifies into a full "explain like I'm five." Reach for `~:` when
# you want a smart colleague's plain answer, `:~` when you want the kids' version.
#
# HOW TO REUSE IT (type this in chat) on any jargon-dense reply:
#     |~:^-1        (plain, professional)
#     |:^-1         (full ELI5)
#
# Run:  ./examples/idiom-aur1-12-plain-english.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
{"role":"assistant","content":"The p99 latency regression is caused by lock contention on the connection-pool mutex during cache-stampede events, so we should implement request coalescing with a singleflight pattern to deduplicate concurrent identical queries."}
]}
JSON

say "THE PLAIN-ENGLISH   ~:^-1   — strip an agent's jargon-dense answer to plain, accurate language"
echo "  the agent's jargon: 'p99 latency regression … lock contention on the connection-pool mutex … singleflight …'"
echo -n "  ~:^-1 => "; "$NLIR" -e "~:^-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/          /'

say "Order matters: ~: (simplify then distil) = crisp professional plain; :~ (distil then simplify) = full ELI5. Reach for ~: for a smart colleague's answer, :~ for the kids' version."
