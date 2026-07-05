# Session summary — showcase: runnable proofs for my multi-message cards

## Goal
Harry's "make sure we're REALLY executing, not theory" bar + aur-1's verify-showcase.py (which defers ^-reading cards to examples/*.sh). Make all 3 of my showcase cards provably real executions.

## After state
- catchup card already proven by examples/golf-msm0-16-catchup.sh.
- Added examples/showcase-msm0-exec-brief.sh (@~0^*-1 on a 5-turn incident thread) and examples/showcase-msm0-ticket.sh ([#~0^*-1, ~0^*-1] on a 5-turn scoping thread). Both dogfood-run live, produce real generated output (varies run-to-run — proof it's not hand-authored), and match the golf-msm0 script format (NLIR/CFG/LITELLM handling, context heredoc, trap cleanup).
- Now every msm-0 showcase card (catchup/exec-brief/ticket) has runnable proof, satisfying verify-showcase.py's "^-cards proven by their examples/*.sh".

## Diff summary
- Files: examples/showcase-msm0-exec-brief.sh (new, +x), examples/showcase-msm0-ticket.sh (new, +x).
- Tests: both scripts executed live; real output captured.

## Operator-takeaway
Provenance discipline: every showcase card that reads chat context has a runnable examples/*.sh that reproduces it against the live binary. Nothing in the showcase is hand-written.
