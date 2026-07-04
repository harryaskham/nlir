#!/usr/bin/env bash
# nlir-golf · aur1 · #103 — "the interpreter" (distil the user's message to its core, then expand it)
#
# When someone types a long, tangled, thinking-out-loud message, `>~^_-1` reads it back to them
# as what they're ACTUALLY wrestling with. `^_-1` is the user's last turn; `~` distils it to its
# core (dropping the surface churn); `>` then expands THAT core into a clear, full articulation.
# Because it summarises FIRST, the expansion re-centres on the real point instead of amplifying
# the ramble.
#
#   THE INTERPRETER   > ~ ^_-1
#     ^_-1 = "ok so i've been staring at this for an hour going back and forth, part of me wants
#             to rewrite the whole module but part thinks that's insane and i should just patch
#             the one function, but the patch feels gross and i don't know, what do you even do"
#     ~^_-1  → "The user is torn between rewriting the whole module or patching one function,
#              and neither feels satisfying."                              ← the CORE
#     >~^_-1 → "You're stuck between two options and can't settle. Neither feels right: the
#              rewrite is appealing in principle but daunting in practice, while the quick patch
#              is tempting but feels wrong…"                               ← the INTERPRETATION
#
# It's the message-version of my #55 deep-dive (`>~x`): distil, then expand the distillate. The
# difference from #76 spec-out (`>^_-1`, which elaborates the LITERAL message) is the `~` in the
# middle — spec-out amplifies what they said; the interpreter first finds what they MEAN, then
# says that clearly and fully. The "let me make sure I understand" move, run on a message.
#
# Run:  ./examples/golf-aur1-103-interpreter.sh
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
{"role":"user","content":"ok so i've been staring at this for like an hour and i keep going back and forth, part of me wants to just rewrite the whole module but part of me thinks that's insane and i should just patch the one function, but the patch feels gross and i don't know, what do you even do here"}
]}
JSON

say "THE INTERPRETER  >~^_-1  — distil the user's last message to its CORE (~), then expand THAT (>)"
echo -n "  ~^_-1  (their CORE)         => "; "$NLIR" -e "~^_-1"  --context-file "$CTX" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >~^_-1 (the INTERPRETATION) => "; "$NLIR" -e ">~^_-1" --context-file "$CTX" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "The message-version of #55 deep-dive (>~x). vs #76 spec-out >^_-1 (elaborates the LITERAL message) — the ~ here finds what they MEAN first, then says it clearly. The 'let me make sure I understand' move."
