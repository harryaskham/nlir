#!/usr/bin/env bash
# nlir showcase · msm1 · FUSION — exact computation OVER meaning (the "why nlir")
#
# This is the headline COMPANION to move-msm1-mathy.sh. That gallery is the EXACT
# SUBSTRATE — deterministic, offline, CI-gated arithmetic, which on its own is just
# functional / array programming (numpy, APL, J do it). THIS script is what actually
# makes nlir distinctive: a SEMANTIC operand riding on that exact scaffolding. Every
# tile below fuses two halves neither tool has alone —
#   • the SEMANTIC half (retrieve world-knowledge, judge meaning, transform language):
#     numpy / APL / J have NO notion of meaning.
#   • the EXACT half (sum / count / mean / verify): a raw prompt can't be TRUSTED with it.
# nlir does BOTH in one line:  describe in meaning -> compute exactly -> gate honestly.
#
# ── LIVE / MODEL-DEPENDENT ────────────────────────────────────────────────────────
# Unlike the det-math gallery, these tiles CALL THE MODEL, so they are NOT CI-gated
# and NOT reproducible-exact. The meaning is the model's; the STRUCTURE / arithmetic is
# exact. Outputs shown are one capture (ms-mac). SUM-world-knowledge and COUNT-by-
# meaning are triple-verified stable across ms-mac + helsinki + aurora; borderline
# judgments vary by transport — that's honest, so we GATE them with self-verify and
# never hard-assert a magic number. Run it live to watch meaning compute exactly.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
why() { printf '   \033[2m(%s)\033[0m\n' "$1"; }
# runfz EXPR — evaluate a LIVE fusion expression. Makes a model call; NOT CI-gated.
runfz() { printf '  => '; "$NLIR" --config "$CFG" --quiet -e "$1" 2>&1 | paste -sd' ' -; }

say "SUM WORLD-KNOWLEDGE — exact arithmetic over facts the model retrieves"
why "the atomic numbers come from MEANING (nothing written out); the sum is EXACT — numpy needs a lookup table, a prompt fumbles the addition"
runfz "\$fold%({\$0+\$1},\$map%({'the atomic number of '..\$0},['gold','iron','oxygen']))"
#  => 113   (79 + 26 + 8; triple-verified ms-mac + helsinki + aurora)

say "MEAN OVER RETRIEVAL — the average of retrieved facts, exactly"
why "same retrieval, divided by the count; _precision is display-only, the value stays exact"
runfz "_precision=2;\$fold%({\$0+\$1},\$map%({'the atomic number of '..\$0},['gold','iron','oxygen']))/3"
#  => 37.67   (113 / 3)

say "COUNT BY MEANING — a semantic predicate fused with an exact count"
why "the model judges each message by MEANING; the COUNT is exact — numpy can't judge 'urgent', a prompt can't be trusted to count"
runfz "\$fold%({\$0+\$1},\$map%({\$0~>'is genuinely urgent'},['server is on fire','update your bio sometime','customer data is leaking']))"
#  => 2   (server-fire + data-leak; NOT the bio nudge; triple-verified)

say "SELF-VERIFY — the move that makes the fuzzy TRUSTWORTHY"
why "the program carries its own correctness proof: a semantic step GATED by a CONTENT check. (never a style/register meta-property — 'is it formal?' flakes on every transport; ~> is entailment, register is not)"
runfz "j={\$if%(\$0~>\$1,\$1~>\$0,false)};\$j%('the meeting starts at noon','the meeting begins at 12pm')"
#  => true   (self-JUDGE: two phrasings, each entails the other -> semantically equivalent)
runfz "j={\$if%(\$0~>\$1,\$1~>\$0,false)};\$j%('the cat is black','the dog is white')"
#  => false  (the judge CATCHES non-equivalence)
runfz "out=@'the meeting is at 3pm';\$out~>'the meeting is at 3pm'"
#  => true   (FACT-SURVIVAL: formalize the note, verify the time fact SURVIVED the transform)
runfz "out=@'the meeting is at 3pm';\$out~>'the meeting is at 9am'"
#  => false  (the gate catches a lost / changed fact)

say "why nlir? — describe in meaning → compute exactly → gate the fuzzy honestly"
why "numpy has no meaning; a raw prompt has no exactness; nlir fuses both in ONE line. The det-math gallery (move-msm1-mathy.sh) is the exact spine this rides on — this is the reason you reach for a natural-language IR instead of an array language or a bare prompt."
