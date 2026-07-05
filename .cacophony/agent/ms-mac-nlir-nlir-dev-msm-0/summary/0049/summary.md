# Session summary — showcase: THE TONE KNOB grid card + driver-relative role note

## Goal
Harry's showcase directive; msm-0 lane. Make the tone-knob (register over a SELECT) learnable as one grid; pin the driver-relative role clarification.

## After state
- New GRID card THE TONE KNOB `[@~0^*-1, :~0^*-1, ~0^*-1]` — one whole-thread SELECT, three registers (@ formal/brief-a-VP · : plain/onboard · ~ terse/standup). Dogfooded live from ONE run on the incident thread (consistent context) → showcase/nlir-tone-knob.png (verified: clean, sigils literal). Ties together EXEC BRIEF + PLAIN RECAP + STANDUP as one teaching unit.
- Runnable proof: examples/showcase-msm0-tone-knob.sh (grid cards aren't auto-verified, so this is their proof).
- Pinned the DRIVER-RELATIVE role note in CATALOG-msm0.md (owed to aur-0): plugin → `^_`=you (Harry), `^`=the agent; agent-driven → `^_`=the user, `^`=us. Same sigils, mirrored by seat.

## Diff summary
- Files: scripts/build-showcase.py (+tone-knob GRID card), examples/CATALOG-msm0.md (+driver-relative note), examples/showcase-msm0-tone-knob.sh (new,+x), showcase/nlir-tone-knob.png (new).
- Tests: dogfood-run live (3 registers from one run).

## Operator-takeaway
The tone knob: `@~0^*-1` (formal) · `:~0^*-1` (plain) · `~0^*-1` (terse) — identical SELECT, register set by the leading op. Role labels are driver-relative (plugin: ^_=you, ^=the agent).
