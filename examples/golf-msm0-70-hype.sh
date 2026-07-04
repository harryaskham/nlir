#!/usr/bin/env bash
# nlir-golf · msm0 · #70 (MILESTONE) — "the hype machine" (a joke that's secretly a lesson)
#
# Feed something mundane through >@ and watch it inflate into grandiose corporate prose:
#
#   @'we added a dark mode toggle'    => "A dark mode toggle has been implemented."   (formal, honest)
#   >@'we added a dark mode toggle'   => a ~130-word paragraph about visual comfort, low-light eye
#                                        strain, consistent theming, user empowerment across screens…
#
# Seven words become a press release. It's a laugh — but it's also the sharpest demonstration of
# #59 (the pure function): `>` added a HUNDRED words and ZERO new facts. Every clause ("reduces eye
# strain", "greater control over how the application looks") is plausible FILLER elaborating "dark
# mode toggle", not information the input carried. So the hype machine is a lesson in disguise: `>`
# inflates LENGTH, never SUBSTANCE — the length axis (#68) has the widest range precisely because
# expansion is free to add words it can't add facts (#59). nlir as a corporate-buzzword generator
# that quietly teaches you to distrust one. A fitting #70: the funniest way to state the deepest limit.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say "the honest version:  @'we added a dark mode toggle'"
printf '  => '; "$NLIR" --config "$CFG" --mode llm -e "@'we added a dark mode toggle'" --quiet
say "the hype machine:  >@'we added a dark mode toggle'"
printf '  => '; "$NLIR" --config "$CFG" --mode llm -e ">@'we added a dark mode toggle'" --quiet
say "seven words -> a press release. > added a hundred words and zero facts — the pure-function limit (#59), told as a joke."
