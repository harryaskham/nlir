# Session summary — semantic-access reliability + SPEC caveat (bd-429d87)

## Goal

Persistent nlir-dev. Engaged the live "mathy golf" round (@msm-0 called @msm-3 in
by name). Turned golf into empirical language science: measure how reliable
semantic access `..` actually is on the DEFAULT transport, and land the finding
durably.

## What landed

- **bd-429d87** (filed): durable reliability finding — semantic-access `..`
  reliability depends on ACCESS KIND. Live data (ms-mac sonnet CLI):
  - `'perfect'..2` ×3 → 28,28,28 · `'perfect'..3` ×3 → 496,496,496 (distinctive
    named constants: rock-stable recall).
  - `'primes'..5` ×3 → 11,7,7 (ordinal index: FLAKY within one transport —
    sporadic enumeration slip, not deterministic-wrong).
  - `'primes'..10`→29, `'fibonacci'..12`→144 correct → weakness is sporadic, not
    "all ordinals bad".
  - Cross-transport: the 40B leader `{$0+$1}⊘({'primes'..$0}↦[1,2,3,4,5])` → 28
    helsinki vs 24 ms-mac (because `'primes'..5` gave 7).
  - The IRONY: robustness and computed-ness ANTI-CORRELATE — terse+robust+recall
    (`'perfect'..2`, 12B) OR computed+fragile (40B prime-fold), never
    terse+robust+computed except via DET-MATH.
- **SPEC.md** (landed on main `38f725b`): new **Access kind** caveat on the `..`
  bullet — distinct from the existing seed-ambiguity note. "An unambiguous seed is
  necessary but not sufficient… prefer deterministic math for asserted/shipped
  values; reserve `..` for live demos where the supply may vary/err."
- **bd-3a589a** (strengthened): appended cross-transport VALUE-divergence evidence
  — a second reproducibility axis beyond the seed gap; a seed-honoring backend is
  necessary-but-not-sufficient, the flakiness is upstream of seed.

## Offline falsifications (saved the fleet live calls)

- 38B paren-drop `{$0+$1}⊘{'primes'..$0}↦[…]` BREAKS: ↦/⊘ are BOTH priority-8
  left-assoc, so ⊘ eats the map-form; 40B parens are load-bearing.
- 36B `↦"12345"` index-trick DEAD: ↦ maps a string as ONE item
  (`{$0++$0}↦"123"`→`123123`).
- string→list coercion under ⊘ does NOT hold (`⊘'first 5 primes'` echoes the
  string) — independently confirmed by @msm-0/@aur-2.

## Verification

- `nlir test`: 138 passed / 0 failed. `verify-spec-ops.py`: OK (36 operators in
  sync). Docs-only change; rebased clean onto main (redundant local commit dropped).

## Status / handoff

Round's card policy converged (fleet consensus): DET-MATH = the only assertable
tier (hard-assert, model-free); distinctive-constant semantic = robust "wow" but
caption as RECALL; ordinal/fold-semantic = live-demo only (flaky). Open follow-ups
in bd-429d87: larger stability sample (N≥10), and a per-transport `..` reliability
matrix (helsinki + :4000 proxy) to feed card model-pinning. aur-1's numeric-`..`→
range op (in flight) would moot the paren-load-bearing issue and golf every
sequence-map shorter.

## Operator-takeaway

Golf surfaced a real reliability law: nlir's "math by meaning" is trustworthy when
the answer is a distinctive RECALLED fact, and shaky when it makes the model COUNT
— so the honest showcase asserts only deterministic math and shows semantic access
as a live illustration, never a hard number. That caveat is now in the normative
SPEC.
