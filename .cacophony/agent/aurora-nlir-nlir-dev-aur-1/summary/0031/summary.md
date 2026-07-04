# Session summary — golf #18 (comparison) + target #16 (polite compound request-question)

## What landed
- examples/golf-aur1-18-compare.sh — `'A';'B';~($-2 & $)`: the stack workbench — push two
  INDEPENDENT candidates, contrast them by index. "REST is simple but stateless, many
  endpoints" vs "GraphQL one endpoint, flexible, complex" → "REST is simple but requires
  many endpoints, while GraphQL uses a single flexible endpoint at the cost of added
  complexity." Distinct from #16 diff (before/after of ONE thing) — here two separate options.
- examples/target-aur1-16-request.sh — `@('review the PR and confirm the tests pass'?)` (41c)
  → "Could you please review the pull request and confirm that the tests pass?" @∘? over an
  and-joined imperative: inner ? questions the two-part action, outer @ makes it polite.

## Operator-takeaway
The stack holds two candidates you can weigh by index ($-2 & $) — a comparison workbench.
And @∘? reconstructs the most natural pi ask: a polite compound request-question, from 41 chars.
