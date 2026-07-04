#!/usr/bin/env bash
# nlir-golf · msm0 · #28 — "register/content near-orthogonality" (~ robust, # fragile)
#
# @ is meant to change ONLY register (aur-1's saturation, #23). So is it transparent
# to the content extractors ~ and #? i.e. does formalising-first change the summary
# or the subject? Tested — and the answer splits, revealing which extractor is robust:
#
#   ~@x  ≈  ~x   ->  HOLDS.  The gist survives; only the tone bleeds a touch.
#   #@x  ≈  #x   ->  FAILS!  #x = "PR review"  but  #@x = "Retry logic".
#
# @ preserves the FACTS but REDISTRIBUTES emphasis, and # (which must pick ONE noun
# phrase) is sensitive to emphasis, so it lands on a different subject after @. ~
# (which keeps the whole gist) shrugs the perturbation off.
#
# LAW: register and content are NEAR-orthogonal — @ moves mostly on the register
# axis but perturbs emphasis. ~ = ROBUST content (invariant to register AND to the
# framing of #27); # = FRAGILE single-subject (sensitive to BOTH framing (#27) and
# register (#28)). Reach for ~ when you need stability; # only when one word is enough.
#
# Real output (claude-sonnet-5), x = a casual "take a look at the PR, retry logic needs review":
#   ~x  => "Requesting a review of a PR—mostly minor changes, but the retry logic needs careful attention."
#   ~@x => "Please review the pull request when convenient, paying special attention to the retry logic."
#   #x  => "PR review"        #@x => "Retry logic"        (subject SHIFTED under @)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }
X="hey can u take a look at the PR when u get a sec, mostly small stuff but the retry logic needs a real review, no rush"

say '~ is register-ROBUST: ~@x ≈ ~x (gist survives)'
printf '  ~x  => '; run "~'$X'"
printf '  ~@x => '; run "~@'$X'"
say '# is register-FRAGILE: #@x ≠ #x (formalising shifts the extracted subject)'
printf '  #x  => '; run "#'$X'"
printf '  #@x => '; run "#@'$X'"
say "@ preserves facts but redistributes emphasis; ~ ignores it, # amplifies it. Content axis: ~ robust, # fragile."
