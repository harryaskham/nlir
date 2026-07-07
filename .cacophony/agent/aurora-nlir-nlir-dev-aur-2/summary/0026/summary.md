# Session summary — "why nlir, not a prompt" example moves (sgu24-app critique)

## Goal

sgu24-app broadcast that the nlir examples read as generic LLM usage, not nlir-
specific. Fleet converged on a test (aur-1's framing): an example is nlir iff it
MIXES det+fuzzy, is a few sigils where a prompt is a paragraph, or lives mid-pipe.
Lane split: msm-0 = pipe family (B), aur-2 (me) = terse agent-shorthand (A) + the
`=>` rework, aur-1 = det-structure/SPEC gate, aur-0 = live+det gate. This slice:
my family-A move contributions, live-captured via helsinki (nighttime, proxy clear).

## Bead(s)

- No bead (fleet-wide examples-quality effort from sgu24-app's broadcast). Directly
  addresses the critique of my earlier `=>` examples (bd-13d9a0) being generic.

## Before state

- examples/move-aur2-generate.sh was the WEAKEST example: standalone `=>` (haiku,
  "write a reply") — exactly "generic LLM, any chatbot does this".

## After state

- NEW examples/move-aur2-decide.sh — the family-A star: `$if%('the server keeps
  crashing'~>'urgent','escalate','queue')`. Fuzzy-classify (~>) drives a DET branch
  ($if) → clean routed token. KILLER teaching contrast (live-verified): the SAME
  expression is `queue` in --mode det (exact keyword-match: no literal "urgent") vs
  `escalate` in llm (semantic: crashing IS urgent) — the difference between the two
  outputs literally IS the fuzzy ~>. That is "why nlir, not a keyword grep".
- REWORKED move-aur2-generate.sh — honest reposition of `=>`: it's the ESCAPE HATCH
  for open-ended generation (bare `=>"write X"` IS just a prompt); it earns its
  place only by splicing live context tersely (`t=^_-1;=>"...: $t"`) and/or being
  COMPOSED with det ops — never dashing off a standalone haiku. Notes the structural
  ops (@/:/~/#) are terser when they fit.
- Live-verified both on helsinki (claude-sonnet-5): decide -> escalate (det ->
  queue), generate -> a one-sentence billing-rewrite risk. bash -n clean.
- Coordinated: aur-1's shape catalog (scratch note nlir-example-shapes-catalog),
  msm-0 owns pipe family B, aur-0 gates. `_seed` (bd-72d6d3, for rigorous golf) is
  msm-3's.

## Diff summary

- Files: examples/move-aur2-decide.sh (new), examples/move-aur2-generate.sh (rework).
  Move scripts only — no phrasebook.md edit (avoid collision with concurrent
  multi-agent example work); phrasebook references to follow once the surface settles.

## Operator-takeaway

The examples now pass sgu24-app's test in my lane: the fuzzy-decision move shows a
det+fuzzy mix whose det-vs-llm output difference (queue vs escalate) is a one-glance
proof of what the fuzzy operator buys you, and the `=>` move is honest that free
generation is the least nlir-specific thing — reframed as a composed escape hatch,
not the flagship. Groundwork for the fleet's nlir-golf / "why nlir" site push.
