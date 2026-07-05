# CATALOG-aur0.md — the considered-reply grammar (aur-0)

aur-0's showcase lane: **grounding/reference** + **self-reflection** — the moves for
replying *in context* and for operating on *your own output*. Where aur-1 maps reply/amend,
aur-2 the `@&[...]` composer, and msm-0 multi-message select, aur-0 maps **how a reply
earns its weight**: by citing what was already said, and by turning back on itself.

Every move below is a REAL live execution — run its `examples/move-aur0-*.sh` to reproduce
it, and see its card in [`showcase/`](../showcase). All read live chat (`^`) or reuse your
own draft (`=`/`$`), so they're built for talking to an agent through the pi plugin.

---

## Part 1 — GROUNDING / REFERENCE  (make your reply cite the conversation)

The engine: `^` = the agent's side, `^_` = yours — and it's *relative to who's driving* (in the
pi plugin, `^_` = you, `^` = the agent you're replying to). `^-1` = their last message,
`^_-1` = your last; `0^_-1` = their WHOLE side (every turn, as a range over the role channel).
Weave turns into a reply with `&`; set the register with a leading `@`/`:`/`~`.

### THE GROUNDED COUNTER — `@(^-1 & '<amendment>' & ^_-1)`
Reply to their suggestion, fold in your change, and ground it in an earlier constraint.
*When:* you're saying "yes, but —" and want to remind them why. (card: grounded-counter)

### THE CITED SYNTHESIS — `@~(0^_-1)`
Read their WHOLE side of the chat (`0^_-1` = every one of their turns) and distil the scattered
ask into one crisp position — "here's what you're really asking for," however many messages it
took. *When:* the ask came out in pieces and you want to name it. (card: cited-synthesis)

### THE FULL LAYERED REPLY — `k=@(^-1 & '<mod>' & ^_-1 & '<caveat>');[$k,~$k]`
The whole considered response in one line: reply + modify + reference + caveat + restyle,
then a reflection on your own summary. *When:* a real, high-stakes reply. (card: full-layered-reply — the flagship)

---

## Part 2 — SELF-REFLECTION  (operate on your own output)

The primitive: **`k=X;…`** — bind your output to `k` with `=`, then reference it again as
`$k`. That `=` binding IS the self-reference; no new operator needed (`&[X,~X]` recomputes;
`k=X;…` computes once and reuses). This is what makes "reflect on what I just wrote" possible.

### THE SELF-SUMMARIZING MEMO — `k=>@'X';[$k,~$k]`
Write a formal memo, then addendum a reflection on its own gist. *When:* a long note that
also needs a one-line TL;DR. (card: self-summarizing-memo)

### THE SELF-RED-TEAM — `k=@>'X';[$k,>!~$k]`
Write your proposal, then emit the strongest developed case AGAINST its own gist
(`>!~$k` = expand·negate·summarise your own draft). *When:* pressure-test before you
send. (card: self-red-team)

---

## The one lesson
A reply is stronger when it (a) points at what's already been said, or (b) turns and
examines itself. nlir makes both a few sigils: `^_-N` cites, `k=X;…` reflects. Learn those
two hooks and the whole considered-reply grammar opens up.

(Runnable proofs: `examples/move-aur0-*.sh`. Shared cross-agent phrasebook: scratch note
`nlir-power-moves`. Verified by `scripts/verify-showcase.py` + the move-*.sh executions.)
