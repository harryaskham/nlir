# Session summary — golf rally: `..` semantic-access site card (sol..3 → Earth)

## Goal

Join Harry's "nlir golf" team rally — use the golf game to pinpoint the
language and mint "why nlir, not a prompt" examples for the site. Golf Round 1
(target "Earth"), then convert the win into a durable, non-colliding site
deliverable.

## Bead(s)

- `bd-e84379` — showcase+examples: `..` semantic-access "why nlir" card
  (sol..3 → Earth, 6-char golf winner). Filed + claimed this session.

## Before state

- Round 1 leader was aur-0's `'sol'..3` (8 chars → "Earth"); msm-0 had just
  declared it "unbeatable-elegant".
- The showcase (scripts/build-showcase.py → showcase/*.png → site) had NO `..`
  semantic-access card at all, despite `.`↔`..` (structural vs semantic access)
  being a signature language duality. Only msm-0's phrasebook descriptor row
  existed.
- verify-showcase (det-only): green.

## After state

- Golfed Round 1 to `sol..3` — **6 chars** → "Earth", beating the 8-char
  leader. `sol` is a bare literal ([a-zA-Z0-9]+), so the quotes on `'sol'` are
  dead weight; det-proof: `sol..3` and `'sol'..3` both reduce to the identical
  ast `(sol .. 3)` and identical det stub `item 3 of: sol`. Independently
  live-verified → "Earth" by msm-0 and aur-0 (referee), and by this session's
  own live run.
- New showcase card `semantic-access`: `'the planets from the sun'..3` → "Earth"
  (the unambiguous, drift-free site card per aur-0/msm-0 consensus). PNG
  rendered.
- New proof script `examples/golf-msm2-01-earth.sh`: det stub always runs
  (proves the quote-shed is structural); llm run lands "Earth" when creds
  present. Exits 0 keyless.
- verify-showcase (det-only): still green, 0 failed; the new card is correctly
  handled as a non-exact llm card.

## Diff summary

- Code/content commit: `54f44b4` (`bd-e84379`).
- Files touched: `scripts/build-showcase.py` (+1 SIMPLE card),
  `examples/golf-msm2-01-earth.sh` (new, +exec), `showcase/nlir-semantic-access.png` (new).
- Tests: no test count change; verify-showcase --det-only green (2 exact / 8
  ran-non-empty / 0 failed); verify-spec-ops unaffected (no operator-table change).
- Behavioural delta: the site gains its first `..` semantic-access card; the
  golf leaderboard gains a confirmed 6-char Round-1 winner.

## Embedded artefacts

- `showcase/nlir-semantic-access.png` — the rendered site card
  (`'the planets from the sun'..3` → Earth, pill "llm · semantic index").

## Operator-takeaway

The golf game did exactly what Harry wanted — playing it pinned down a real,
reusable language fact: **any single-token quoted operand can shed its quotes
for a free 2-char save** (`'sol'..3` → `sol..3`), which is why "Earth" golfs to
six characters of pure meaning with zero string lookup. That win is now a
first-class site card teaching the `.`↔`..` (structural↔semantic access)
duality — the showcase's first `..` example. Robust site expr is the
unambiguous `'the planets from the sun'..3`; `sol..3` is the wow floor in the
caption.
