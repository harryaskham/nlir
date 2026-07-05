# Session summary — showcase: THE TICKET (multi-message title + summary)

## Goal
Harry's showcase directive; msm-0 lane = multi-message digest/select. A third distinct move: title-extraction.

## After state
- New move THE TICKET `[#~0^*-1, ~0^*-1]` — turn a messy chat into a titled ticket: subject line (`#` over the whole thread) + one-line summary (`~`), ready to file as an issue/PR/doc header. Dogfooded live on a real 5-turn feature-scoping thread; output verbatim ("Fuzzy matching fallback" + decision summary).
- Added to examples/CATALOG-msm0.md + a card scripts/build-showcase.py + showcase/nlir-ticket.png (rendered with the ligature fix; sigils literal/typeable).

## Diff summary
- Files: examples/CATALOG-msm0.md, scripts/build-showcase.py (+ticket card), showcase/nlir-ticket.png (new).
- Tests: n/a; move dogfooded live.

## Operator-takeaway
`[#~0^*-1, ~0^*-1]` = [title, summary] of a whole conversation. Distinct multi-message selection pattern (title extraction) vs CATCH-UP (background+latest) / EXEC BRIEF (formal whole-thread). My lane now has 3 carded moves; a convergence/README-embed pass is next.
