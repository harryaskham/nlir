# nlir POWER MOVES — a compressed language of thought

nlir turns a few sigils into a rich, real message. This is a phrasebook of **reusable idioms**:
learn a shape, fill the slots, and get a whole considered communication act — a reply, a proposal,
a review, a catch-up — in one line you can type straight into pi via the nlir plugin.

Every move here is a **real execution**: each `examples/move-*.sh` runs the nlir binary live and
captures the output, and deterministic showcase cards are re-run + asserted by
`scripts/verify-showcase.py` (a CI gate). Nothing here is theory.

---

## The model: SELECT ∘ TRANSFORM ∘ COMPOSE

A move is built from three kinds of step, and they nest:

1. **SELECT** what you're acting on — a literal `'...'`, or a slice of the live chat via message
   ranges: `^-1` (last), `^_-1` (their last), `0^*-2` (all but the last), ...
2. **TRANSFORM** it — `@` formalise · `:` simplify/plain · `~` distil · `>` expand · `#` subject ·
   `!` negate.
3. **COMPOSE** several pieces into one — `&[a, b, c]` weaves them into one coherent text.

Three **dials** turn the output without changing the content:

| dial | sigils | picks |
|------|--------|-------|
| **tone** | `@` formal · `:` warm/plain · `~` terse | the register |
| **role** | `^` the agent (assistant) · `^_` you, the driver (user) · `^*` all · `^/` system | whose words |
| **time** | `^-1` last · `^_0` first · `0^*-2` a range | which turns |

> Role is **driver-relative**: roles are fixed as assistant (`^`) and user (`^_`), and in the pi
> plugin YOU are the user — so `^_` = your turns, `^` = the agent's turns.

All three composing: `@&[:~0^_-1, 'my amendment', 'my caveat']` = weave [a plain digest of the user's
whole ask, my amendment, my caveat] into one formal reply.

---

## Quick reference (fill the CAPS, type it into pi)

| move | shape | intent | lane |
|------|-------|--------|------|
| counter-reply | `@&[:THEIR_POINT, STANCE, CHANGE, CAVEAT]` | reply: agree, amend, caveat | aur-2 |
| weighed recommendation | `@&[:OPTION_A, :OPTION_B, VERDICT]` | two options + your call | aur-2 |
| partial-accept | `@&[ACCEPT, !REJECT+reason, ALTERNATIVE]` | yes to part, no to part, instead | aur-2 |
| empathetic redirect | `:&[VALIDATE, AGREE, REFRAME, FIX]` | warm de-escalation | aur-2 |
| review verdict | `@&[GOOD, GAP, FIX, VERDICT]` | review work: praise/gap/fix/call | aur-2 |
| terse status | `~&[DONE, BLOCKED, NEXT]` | a standup in one line | aur-2 |
| crisp proposal | `@&[:PROBLEM, FIX, TRADEOFF, ASK]` | a mini-RFC | aur-2 |
| scoped commitment | `@&[DELIVERABLE, BY_WHEN, DEPENDENCY]` | a promise + its fine print | aur-2 |
| considered reply | `@(^-1 & 'AMENDMENT')` | amend the agent's last suggestion | aur-1 |
| reasoned no | `@(!^-1 & 'GROUNDS')` | decline, with your reason | aur-1 |
| honest yes | `[@(^-1 & 'AMENDMENT'), ~>!^-1]` | yes + an auto devil's-advocate | aur-1 |
| grounded counter | `@(^-1 & 'CHANGE' & ^_-1)` | reply grounded in an earlier point | aur-0 |
| full layered reply | `k=@(^-1 & 'CHANGE' & ^_-1 & 'CAVEAT');[$k,~$k]` | the whole considered response + self-reflection | aur-0 |
| self-red-team | `k=@>'DRAFT';[$k,>!~$k]` | your draft + its strongest rebuttal | aur-0 |
| catch up | `p=~0^*-2;[$p,^_-1]` | rejoin a thread: background + their live question | msm-0 |
| exec brief | `@~0^*-1` | whole thread → a VP-ready paragraph | msm-0 |
| standup | `~0^*-1` | the whole thread in one line | msm-0 |
| the two sides | `[~0^_-1, ~0^-1]` | split a debate by side | msm-0 |

(Full slot rules + more moves per lane below and in each `CATALOG-<lane>.md`.)

---

## The lanes

### COMPOSE — weave several points into one (aur-2)
`@&[SLOT, SLOT, ...]` — the composer workhorse. Fill the slots for any intent; the **leading op is
the tone knob** (`@`/`:`/`~`); each **slot is transformable** (`:` plain a point · `!` reject a
claim · `~` digest a long reference). Gotcha: flag a *gap* plainly, don't `!` it (that flips its
meaning); keep slots consistent.
Moves: diplomatic counter-reply · weighed recommendation · partial-accept counter-offer ·
empathetic redirect · briefed handoff · review verdict · terse status ping · crisp proposal ·
scoped commitment.
→ `examples/CATALOG-aur2.md` · `examples/move-aur2-*.sh` · cards `nlir-composer-reply`, `nlir-empathetic-redirect`

### REPLY / AMEND — answer a live suggestion (aur-1)
`@(^-1 & '<your amendment>')` — take the agent's last suggestion, fold in your twist, make it formal
(the grouping is load-bearing).
Moves: considered reply (agree+amend) · honest yes (amend + auto devil's-advocate `~>!^-1`) ·
reasoned no (`@(!^-1 & grounds)`) · decisive close (end a thread with a decision).
→ `examples/CATALOG-aur1.md` · cards `nlir-considered-reply`, `nlir-honest-yes`, `nlir-reasoned-no`, `nlir-decisive-close`

### GROUND / REFLECT — reference prior context + red-team yourself (aur-0)
`@(^-1 & mod & ^_-1 & caveat)` grounds a reply in an earlier point; `k=X;[$k,~$k]` binds your output
and reflects on it (the `=` binding IS the self-reference — no new operator needed).
Moves: grounded counter · cited synthesis · **full layered reply** (the flagship — Harry's whole
example: reply + modify + reference + caveat + restyle + self-reflect, in one line) ·
self-summarizing memo · self-red-team (`k=@>'X';[$k,>!~$k]`).
→ `examples/CATALOG-aur0.md` · `examples/move-aur0-*.sh` · cards `nlir-full-layered-reply`, `nlir-grounded-counter`, `nlir-self-red-team`

### SELECT / DIGEST — read a whole thread (msm-0)
Range selectors over the chat: `~0^*-1` the whole thread in one line · `p=~0^*-2;[$p,^_-1]` catch up
(background + their live question, verbatim) · `[~0^_-1, ~0^-1]` the two sides of a debate. These
SELECT the input the other lanes TRANSFORM / COMPOSE.
→ `examples/CATALOG-msm0.md` · cards `nlir-catchup`, `nlir-two-sides`, `nlir-exec-brief`, `nlir-ticket`

---

## How the lanes stack
**SELECT** (msm-0) a slice → **TRANSFORM** (aur-1) or **COMPOSE** (aur-2) it → **REFLECT** (aur-0) on
the result. For example:

    k=@&[:~0^_-1, 'but scope it to the mobile client', 'mindful of the Q3 freeze'];[$k,~$k]

= digest their whole ask, weave in your amendment + caveat, formalise it, then append its own gist.
SELECT chooses the words, the tone knob chooses the register, the composer chooses the structure.

---

## See it / run it
- **Cards** (sigils rendered literally + typeably): `showcase/` → the GitHub Pages `showcase.html` gallery.
- **Run any move for real**: `bash examples/move-<lane>-<name>.sh`.
- **Per-lane detail**: `examples/CATALOG-<lane>.md`.
