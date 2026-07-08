# Session summary — golf reliability science + preflight fix + DET-MATH coverage

Persistent nlir-dev (msm-3). One long session across many heartbeats; this
supersedes the earlier reliability-only summary (indices 0010–0013 re-published
the same stale artefact — see the duplicate-summary note at the end).

## Landed on main (all verified)

1. **SPEC `..` reliability caveat** (`38f725b`, bd-429d87) — new "Access kind"
   note distinct from the seed-ambiguity note: an unambiguous seed is necessary
   but NOT sufficient; distinctive named constants recall stably, ordinal indices
   into a counting sequence can be flaky within one transport; prefer det-math for
   asserted/shipped values, reserve `..` for live demos.
2. **preflight nix-dev-shell fail-fast** (`322cca4`, bd-b15ff8 CLOSED) — flake.nix
   devShell exports `NLIR_DEV_SHELL=1`; scripts/preflight.sh fails fast on Darwin
   with a clear `nix run .#preflight` / `nix develop` hint when the marker is
   unset, replacing the cryptic `-liconv` link error. Verified `nix develop
   --command` runs the shellHook.
3. **DET-MATH statistics regression cases** (`1a2e448`, bd-429d87) —
   stats-mean-1-100 (float-division average → 50.5), stats-count-above-mean (self-
   referential stat, binds the mean + $filter/$gt → 5), stats-sum-if-gt5 (fold-
   fusion Bool→Number → 15).
4. **Boolean forall/exists regression cases** (`d39bb5a`, bd-429d87) —
   bool-forall/exists true+false via ∧/∨ fold over predicate-mapped lists (the
   ∧∨ operators had zero test coverage in their reduction role).

## Beads

- **bd-429d87** (OPEN): durable semantic-access reliability finding + card-tier
  policy. Live data: `'perfect'..2/..3` 6/6 stable; `'primes'..5` flaky (11,7,7);
  cross-transport 40B leader 28(helsinki)/24(ms-mac). Robustness ⟂ computed-ness.
  Open follow-ups: larger stability sample (N≥10), per-transport `..` matrix
  (model-heavy — deferred to a workday window).
- **bd-85c49d** (CLOSED): `^` bled stale cross-agent context from the node-global
  `~/.config/nlir/context.json`. I root-caused + reproduced; aur-2 fixed (a928a3d,
  fail-loud one-shot). Deduped msm-0's concurrent bd-b18da7 into it.
- **bd-3a589a** (OPEN, blocked): strengthened with cross-transport VALUE-divergence
  evidence — a seed-honoring backend is necessary-but-not-sufficient.
- **bd-14402e** (OPEN, P4, deliberately deferred): latent arg-eval recursion guard
  gap. My own analysis says DO NOT fix now — untestable/unreachable in shipped
  config (compose sigil shadowed); fix when reachable. Respect this.

## Round outcome

Mathy-golf round fully closed: play surfaced 4 eval gaps → all filled (range,
$len, $gt/$lt/$not + ¬, Gauss card) + my `^` isolation fix + the -liconv
onboarding papercut. My reliability finding anchored the card-policy consensus:
DET-MATH = the only terse+computed+assertable tier.

## Verification / environment

- All landed changes green: nlir test up to 168/168 across the suite; built +
  tested in the nix dev shell (`nix develop --command cargo build/test`).
- Reintegration friction navigated correctly: transient integration-checkout
  fetch wedges (180s) and false-negative `rejected_no_publish` receipts (post-land
  fetch timeouts) — always verified on origin/main, never blind-retried.

## Continuity notes for future-me

- DET-MATH assertable-tier coverage is now broad (range/Gauss/factorial/sum-sq/
  cardinality/iteration/predicate-count/statistics/forall-exists/sort-index).
  Do NOT keep padding it — prefer real features or a clean stand-down.
- No clean self-contained task fit recent constraints (bd-970e05 is big/multi-
  surface/others' active lane; bd-3a589a blocked; bd-6a7359 aur-0's; bd-429d87
  follow-ups model-heavy). Reassess when a new round opens or load/ workday eases.
- DUPLICATE-SUMMARY artifact: each reintegration re-publishes the single tracked
  `summary/0010/summary.md` under the next index, so indices 0010–0013 are
  identical copies. Harmless; keep this file's content current so republishes are
  accurate.

## Operator-takeaway

Golf as play surfaced real gaps and a real reliability law; the team filled the
gaps within the hour and the law is now in the normative SPEC. nlir's "math by
meaning" is trustworthy for distinctive recalled facts, shaky when it must count —
so the honest showcase hard-asserts only deterministic math (now well
regression-covered) and treats semantic access as a live illustration.
