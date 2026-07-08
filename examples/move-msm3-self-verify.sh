#!/usr/bin/env bash
# nlir showcase · msm3 · SELF-VERIFY — how fusion becomes TRUSTWORTHY, not just clever
#
# HONEST FRAMING (2026-07-08, from Harry's "how is this not just array programming?"):
# nlir's differentiator is FUSION — a SEMANTIC step riding on EXACT structure (see
# examples/move-msm1-fusion.sh for the broad gallery, and move-msm1-mathy.sh for the
# offline det SUBSTRATE it rides on). But the semantic half is genuinely fuzzy and
# MODEL-DEPENDENT (bd-429d87): run a count-by-meaning twice and the number can change.
# So the honest question is not "look, it computed X" — it is "how do you TRUST the
# fuzzy step?" The answer, and the point of this deep-dive, is SELF-VERIFY: the program
# checks its own semantic step, and you assert the CHECK (a robust property), never the
# flaky value.
#
# This is a LIVE showcase — it needs a model (llm mode), unlike the offline det
# substrate. Outputs are model-dependent: the FLAKY one below is the lesson; the ROBUST
# ones (fact-survival, self-judge) are the pattern. NEVER CI-assert any of these.
#
# THE ONE RULE (triple-transport-verified — ms-mac + helsinki + aurora, bd-3a589a):
# a self-check must be a CONTENT-ENTAILMENT property (does the output entail a required
# FACT) or a self-JUDGE (two answers semantically equivalent) — NEVER a STYLE/register
# meta-property ("is this formal/polite/casual"). "does <text> entail 'a formal
# message'" is a category error (`~>` is entailment; register is not a logical
# consequence of content) and flakes UNPREDICTABLY on every transport. Content
# entailment held on all three.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
why() { printf '   \033[2m(%s)\033[0m\n' "$1"; }
# run EXPR — evaluate a LIVE (llm-mode) expression; output is model-dependent.
run() { printf '  => '; "$NLIR" --config "$CFG" --mode llm --quiet -e "$1" 2>&1 | paste -sd' ' -; }

say "SELF-VERIFY — making nlir's FUZZY half trustworthy (LIVE; needs a model)"
why "fusion — a semantic step on exact structure — is the 'why nlir'. But the semantic half is model-dependent, so this shows the DISCIPLINE that keeps it honest. Outputs vary run-to-run; that is the whole point."

say "1. THE TEMPTATION — count by meaning (lovely, but NEVER assert the number)"
why "an EXACT fold over a FUZZY per-item test: numpy has no notion of 'a complaint'; a raw prompt cannot be trusted to count. Run it twice — the count can move (1 vs 2) because 'where is my refund?' is borderline complaint-vs-question. THIS is why a fusion VALUE is never hard-asserted."
run "\$fold%({\$0+\$1},\$map%({\$0~>'a complaint'},['my order never arrived','thanks so much, five stars','where is my refund?']))"
run "\$fold%({\$0+\$1},\$map%({\$0~>'a complaint'},['my order never arrived','thanks so much, five stars','where is my refund?']))"

say "2. ROBUST SHAPE — FACT-SURVIVAL: a semantic transform GATED by a content check"
why "rewrite by meaning (@ formalises), then verify the KEY FACT survived. The check is a CONTENT-entailment (does the output entail the fact) — stable, and it DISCRIMINATES: true when the fact is kept, false when it is altered. The program carries its own correctness proof."
run "out=@'the deploy is at 3pm';\$out~>'the deploy is at 3pm'"
run "out=@'the deploy is at 3pm';\$out~>'the deploy is at 9am'"

say "3. ROBUST SHAPE — SELF-JUDGE: are two answers the SAME meaning?"
why "j = does A entail B AND B entail A (bidirectional content equivalence). It judges MEANING, not wording — true for paraphrases, false for different content. This is the exact-regression use of the fuzzy judge (nlir grades nlir)."
run "j={\$if%(\$0~>\$1,\$1~>\$0,'false')};\$j%('the cat sat on the mat','a cat was sitting on a mat')"
run "j={\$if%(\$0~>\$1,\$1~>\$0,'false')};\$j%('the cat sat on the mat','the dog ran in the park')"

say "THE DISCIPLINE — anchor the self-check on a CONTENT fact, never a STYLE property"
why "a robust self-check asserts a CONTENT fact (fact-survival / self-judge). A STYLE meta-property ('is this formal/polite/casual') is a category error and flakes unpredictably on EVERY transport (ms-mac + helsinki + aurora; bd-3a589a) — content-entailment held on all three."
why "the pattern: describe in meaning -> compute/transform exactly -> SELF-VERIFY the semantic step on a content property -> report the CHECK, never the flaky value. That is fusion you can trust — the thing neither numpy (no meaning) nor a raw prompt (no reliable exactness, no composable self-check) can do."
