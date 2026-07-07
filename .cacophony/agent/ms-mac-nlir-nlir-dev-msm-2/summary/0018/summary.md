# Session summary — surface the "why nlir, not a prompt" cards on the site (README)

## Goal

Close the last mile of Harry's rally ask ("put the best ones on site"): the 3
"why nlir" showcase cards landed earlier this session existed as showcase/*.png
on main but were unreferenced, so they didn't actually appear on the site. Wire
them into the README gallery under a "Why nlir, not a prompt?" framing that
directly answers sgu24-app's critique.

## Bead(s)

- `bd-b31517` — README: surface the "why nlir, not a prompt" cards (fuzzy-sum +
  the `.`↔`..` duality) in the site gallery.
- (this session's cards, already landed: `bd-e84379` `..` semantic-access;
  `bd-2b9354` `.` structural-access; `bd-f2c97b` fuzzy-sum.)

## Before state

- README Showreel is a CURATED gallery of specific card names; the 3 new cards
  (semantic-access, structural-access, fuzzy-sum) were on main but referenced
  nowhere, so they were invisible on the site.

## After state

- New README "Why nlir, not a prompt?" block (in the Showreel section, after the
  named-lambda card): features the fuzzy-sum flagship
  (`{$0+$1}⊘([...])` → 10, with the pipe form) and the `.`↔`..` access duality
  as a side-by-side pair (`[Mercury,Venus,Earth,Mars].2` → Earth vs
  `'the planets from the sun'..3` → Earth). All 3 card PNGs now surface on the
  site.

## Diff summary

- Content commit: `bd-b31517` (this commit); final landed squash SHA from the
  reintegration receipt.
- Files touched: `README.md` (+1 additive "Why nlir, not a prompt?" block; no
  card/PNG changes — those already landed).
- Tests: none affected (markdown-only); all 3 referenced PNGs verified present.
- Behavioural delta: the three signature "why nlir" cards are now visible on the
  site with the det+fuzzy / terse→semantic / pipe-native framing.

## Operator-takeaway

The golf→site pipeline is complete end to end: golf mints a shape, agents
referee it live, msm-2 cards it, and now the site's README argues "why nlir, not
a prompt" with those exact cards — the det+fuzzy mix, the terse semantic index,
and the structural/semantic duality. That directly answers the outside feedback
that the old examples read as generic LLM usage.
