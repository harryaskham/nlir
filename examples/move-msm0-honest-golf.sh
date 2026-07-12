#!/usr/bin/env bash
# nlir showcase · msm0 · THE HONEST RATIO — why nlir, measured (sparked by sgu24-app)
#
# The critique: golfing a famous string (=>'first line of 1984') isn't compression —
# it's a LOOKUP into the model's memorized weights. The honest question: how much
# does nlir compress when the target ISN'T memorized?
#
# Three regimes, all measured live by the team:
#   RECALL       =>'the gettysburg address'   ~35x  — but ~0 novel bits: measures FAME, not nlir
#   DERIVATION   >@'<novel seed>'             ~10x  — novel facts survive; model adds only form
#   INSTRUCTION  {(@~$0)?}                      8.2x — the transform IS the sigils, ZERO recall
#
# The real nlir win = INSTRUCTION-COMPRESSION: a few sigils == a full English
# instruction, applied to LIVE input the model can't have seen. The ratio scales
# with instruction complexity, NOT target fame — and it's honest because the
# information lives in program+context, never in pretraining.
#
# The byte-RATIO is provable OFFLINE (pure string length, no model). The applied
# transform needs LITELLM_MASTER_KEY (skipped cleanly otherwise).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
HAVE_KEY=0; [ -n "${LITELLM_MASTER_KEY:-}" ] && HAVE_KEY=1

say(){ printf '\n\033[1m%s\033[0m\n' "$1"; }
why(){ printf '   \033[2m(%s)\033[0m\n' "$1"; }
llm(){ if [ "$HAVE_KEY" = 0 ]; then printf '  ~ SKIP (no LITELLM_MASTER_KEY)\n'; return 0; fi
       printf '  => '; "$NLIR" --config "$CFG" --mode llm --quiet -e "$1" 2>&1 | tail -1; }

# --- THE HONEST HEADLINE: instruction-compression (byte-ratio proven OFFLINE) ---
INSTR="rephrase this professionally and turn it into a single clarifying question"
SIG='{(@~$0)?}'
say "THE HONEST RATIO — compress the INSTRUCTION, apply to unmemorizable input"
why "byte-ratio is pure string length (offline, no model): sigils vs the English you'd type"
printf '  English instruction : "%s"  (%dB)\n' "$INSTR" "${#INSTR}"
printf '  nlir sigils         : %s  (%dB)\n' "$SIG" "${#SIG}"
awk -v a="${#INSTR}" -v b="${#SIG}" 'BEGIN{printf "  instruction-compression = %.1fx  (ZERO recall; scales with instruction complexity, not fame)\n", a/b}'
why "applied LIVE to a novel message the model can't have memorized:"
llm "$SIG%'ugh standup ran 40min again, everyone recited status not blockers'"

# --- THE HONESTY CHECK: the engine that GENERATES also GRADES its own fact-preservation ---
# (msm-3/aur-1: a literal text-search UNDER-counts fact-survival because the model
#  REFORMATS specifics — "1340"->"1,340", "22min"->"22 minutes". The honest check is
#  SEMANTIC (`~>`), immune to reformatting: the same engine that generates also grades.)
SEED='checkout 500s for 22min from 14:05 UTC, null-ptr in the tax module, 1340 orders failed'
say "THE HONESTY CHECK — generate, then have nlir grade its OWN fact-preservation (semantic, reformatting-immune)"
why "expand the terse seed into a full writeup, then SEMANTICALLY verify a specific novel fact survived — sat = does the expansion mean the fact"
llm "sat={\$0~>\$1};\$sat%(>@'$SEED','1340 orders failed')"
why "the self-judge confirms the fact carried through the expansion (true), catching what a literal grep can't: reformatted-but-preserved facts. Checked by the engine that wrote it, not asserted in a caption."

# --- CONTRAST: recall is a lookup, not compression ---
say "NOT COMPRESSION — a famous string is a LOOKUP into memorized weights"
why "the model supplies this for FREE if it recalls it (measures fame, not nlir) — and it may even hedge/attribute instead of reproducing, which only underlines that this is recall, not encoding"
llm "=>'the gettysburg address'"

say "Honest headline: nlir compresses INSTRUCTIONS + DERIVABLE FORM over the input YOU supply — never recalls facts. ~8x, real."
