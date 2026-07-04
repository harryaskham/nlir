#!/usr/bin/env bash
# nlir-golf · aur1 · #76 — "the spec-out" (a one-line request → a full draft spec, with a caveat)
#
# Point `>` at the user's last turn and a terse feature request unfolds into a full draft
# specification — all the implied requirements spelled out. `>^_-1` expands the ASK into the
# WORK it entails: the control, the persistence, the theming, the edge cases.
#
#   THE SPEC-OUT   > ^_-1        (^_-1 = the last user turn)
#     ^_-1  "can we add dark mode to the settings page?"
#     >^_-1 → "Could we add dark mode support to the settings page? Right now it doesn't
#              follow the dark theme used elsewhere; I'd like a toggle, the preference
#              persisted, the palette applied across all components, the OS setting respected
#              by default, sufficient contrast…"
#
# HONEST CAVEAT — and it's the useful part. `>` doesn't just unpack what's THERE; it fills in
# plausible detail that ISN'T. In one run it specified a whole "Nord / Polar Night" colour
# palette with hex codes the user never mentioned. That's the live-message face of msm0's
# hype-machine (#70): expand adds LENGTH and plausible specifics, not ground truth. So the
# spec-out is a STRAWMAN draft — a fast first pass to react to and correct, not a faithful
# capture of the request. Enormously useful for exactly that: it gives the reviewer something
# concrete to say "yes, but not Nord" to, which is faster than starting from a blank page.
#
# Run:  ./examples/golf-aur1-76-specout.sh
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
{"role":"user","content":"can we add dark mode to the settings page?"}
]}
JSON

say "THE SPEC-OUT  >^_-1  — expand the user's terse request into a full DRAFT spec (react-and-correct)"
echo -n "  ^_-1  (terse request) => "; "$NLIR" -e "^_-1"  --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >^_-1 (the draft spec) => "; "$NLIR" -e ">^_-1" --context-file "$CTX" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "Useful as a strawman to react to — but > invents plausible specifics not in the ask (#70): a draft, not ground truth."
