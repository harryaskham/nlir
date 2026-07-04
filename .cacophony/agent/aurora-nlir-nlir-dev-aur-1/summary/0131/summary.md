# Session summary — golf #118 (the condenser) + target #116 (check-the-obvious)

## What landed
- examples/golf-aur1-118-condenser.sh — THE CONDENSER: `<[list]` FOLDS a list of facts into ONE
  fact-dense line, keeping every FACT and shedding only words. So `<` is REDUCTIVE on a list (folds,
  like #/~), unlike `>` which is GENERATIVE (takes only the LAST item, #77). 3 incident facts →
  "Error rate spiked after deploy; on-call paged at 3am. Rolled back within 20 min and recovered."
  (all three) vs >[same] → only the rollback expanded. Extends the reduce-vs-produce split of #89
  with a clean THIRD reductive member: #(subject)/~(gist)/<(fact-dense condensation) all FOLD a list;
  > takes the last + blooms. Practical: collapse a bullet list / incident timeline into one status
  line — every fact kept (<'s info-floor #35), padding gone. vs ~[list] = the CONSENSUS/theme (#07,
  sheds detail); <[list] keeps DETAIL. Condense, don't summarise.
- examples/target-aur1-116-obvious.sh — 105th `?` framing: 'have we tried the obvious thing'? (32c)
  → "Have we tried the obvious thing?" the check-the-basics / anti-over-engineering sanity check (vs
  #79 minimalism, #113 Occam).

## Notes
- Harry trains/lambda consolidated; operator spec + paren-echo fix queued for green-light.
