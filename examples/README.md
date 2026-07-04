# nlir examples — the golf gallery

A living gallery of nlir expressions, built as an overnight two-game challenge
across three agents (aur-1, aur-2, msm-0). Each file is a runnable script whose
header shows the concept, the expression, and a real captured output.

**Two games:**

- **Forward golf** (`golf-<agent>-NN-*.sh`): express the *richest semantic
  concept* in the *fewest sigils* — show off the nested stack machine.
- **Target golf** (`target-<agent>-NN-*.sh`): the reverse — reconstruct a
  realistic pi chat sentence from the *shortest* nlir expression (terse seed →
  full generation). This is exactly how nlir is meant to be used inside pi:
  type `|<expr>` and send the polished result.

**Run one:**

```sh
cargo build --release
NLIR=target/release/nlir bash examples/golf-aur2-theme.sh
```

Deterministic examples (arithmetic, joins, spread) need no API key. LLM examples
call the models in `config.example.yaml` (the `claude`/`sonnet` command backend by
default), so their output is model-dependent — the header sample is illustrative.
See [`cases.md`](cases.md) for the core language reference and the `nlir test`
suite; see [`../SPEC.md`](../SPEC.md) for the full contract.

Operator quick-key: `#` subject · `!` negate · `&` and-join · `|` or-join ·
`?` questionify (postfix) · `~` summarise · `@` formalise · `:` simplify ·
`>` expand · `<` shorten · `+ - * / **` arithmetic · `[a,b]` list (spreads into
variadic ops) · `^`/`^_` message ranges · `;` push · `$` peek/read · `=` assign ·
`"$name"` interpolate.

---

## Forward golf — a concept in minimal sigils

### aur-2 · corpus synthesis, coercion-math, nested logic

| Example | Concept | Expression |
|---|---|---|
| `golf-aur2-theme` | the theme that unifies N documents | `~&[#d1,#d2,#d3]` |
| `golf-aur2-hierarch` | theme-of-themes (tree-recursive, depth-4) | `~&[~&[#,#],~&[#,#]]` |
| `golf-aur2-vibesum` | average vague quantities | `(+['a couple','a dozen',…])/4` |
| `golf-aur2-calc` | natural-language calculator, w/ precedence | `'a dozen'+'a couple'*'a few'` |
| `golf-aur2-split` | semantic bill splitter | `('a hundred'+'a score')/'a handful'` |
| `golf-aur2-counter` | the opposing camp's one-line thesis | `~!&[c1,c2]` |
| `golf-aur2-dilemma` | frame options as the decision question | `|[a,b]?` |
| `golf-aur2-matrix` | a 2-axis options matrix (OR-in-AND) | `~&[|[a,b],|[c,d]]` |
| `golf-aur2-brief` | rough notes → one polished status brief | `@~&[n1,n2,n3]` |
| `golf-aur2-mission` | a list of values → one punchy mission line | `<~&[v1,v2,v3]` |
| `golf-aur2-moral` | the shared moral of two cautionary tales | `#~&[t1,t2]` |
| `golf-aur2-veto` | reject a forced either/or (do neither) | `~!|[a,b]` |

### aur-1 · cognition, the stack machine, register composition

| Example | Concept | Expression |
|---|---|---|
| `golf-aur1-01-cognition` | dialectic / socratic | `~(x&!x)` · `~^-1?` |
| `golf-aur1-02-stackmachine` | RPN arithmetic / stack folds | `3;4;+;5;*` · `n;$;*` |
| `golf-aur1-03-workingmem` | the stack as working memory | `;` / `$` reuse |
| `golf-aur1-04-alignment` | did the answer address the question? | `~(#^_-1 & #^-1)` |
| `golf-aur1-05-recursion` | recursion is intensity (compression dial) | `~x` · `~~x` · `~~~x` |
| `golf-aur1-06-perspective` | perspective-shift (compositional stance) | `@!x` · `[:c,@c]` |
| `golf-aur1-07-consensus` | the emergent position from many opinions | `~[o1,o2,o3]` |
| `golf-aur1-08-steelman` | strongest vs weakest framing | `[>@c, <:c]` |
| `golf-aur1-09-panel` | advocate / skeptic / layperson → verdict | `~[@c,!c,:c]` |
| `golf-aur1-10-drift` | how the conversation's topic moved | `[#^_0, #^_-1]` |
| `golf-aur1-11-faq` | a knowledge-base Q&A row from one doc | `'<doc>';[#$?,~$]` |
| `golf-aur1-12-counterfactual` | the road not taken, fleshed out (premortem) | `>!x` |
| `golf-aur1-13-tempered` | self-critique → the mature position | `~(x & >@!x)` |

### msm-0 · the conversation (ranges, assignment, interpolation)

| Example | Concept | Expression |
|---|---|---|
| `golf-msm0-01-history` | whole-conversation crux / TL;DR | `#~0^*-1` · `~0^*-1` |
| `golf-msm0-02-debate` | debate framer (assignment = value reuse) | `c=~0^*-1;[@$c,:!$c]` |
| `golf-msm0-03-arc` | a conversation's journey in one line | `~(^_0 & ^-1)` |
| `golf-msm0-04-twosides` | each role's whole half | `[~0^_-1, ~0^-1]` |
| `golf-msm0-05-digest` | one summary → a title + a body | `s=~0^*-1;[#$s,$s]` |
| `golf-msm0-06-topics` | split a drifting chat, name each half | `#0^*1 & #2^*-1` |
| `golf-msm0-07-subject` | interpolate an LLM value into a template | `t=#~0^*-1;"re: $t"` |
| `golf-msm0-08-flashcard` | the last exchange as a Q/A card | `q=^_-1;a=~^-1;"Q: $q\nA: $a"` |
| `golf-msm0-09-email` | auto-draft a whole email from a chat | `t=#~0^*-1;s=~0^*-1;"Subject: $t\n\n$s\n\nThoughts?"` |
| `golf-msm0-10-recap` | a thread's through-line from 3 pinpoint reads | `~&[^_0,^-1,^_-1]` |
| `golf-msm0-11-toc` | slice a wandering thread, number the topics | `a=#0^*1;b=#2^*-1;"1. $a\n2. $b"` |
| `golf-msm0-12-status` | wide topic × narrow open-question card | `t=#~0^*-1;o=~^_-1;"Topic: $t | Open: $o"` |

---

## Target golf — reconstruct a chat turn in minimal chars

Winner = closest match, fewest chars. Mechanisms are split so each entry teaches
a different reconstruction move: **`@` formalise** (msm-0), **`>`/`:`/`~>`**
(aur-2), **`?` / nested** (aur-1).

### aur-2 · `:` simplify + `~>` controlled expand (jargon→plain, keywords→line)

| Example | Target (chat turn) | Expression |
|---|---|---|
| `target-aur2-01-review` | "I would appreciate it if you could review my code…" | `@'review my code and give feedback'` |
| `target-aur2-02-plain` | "Your cells contain tiny power plants…" | `:'mitochondria … make ATP …'` |
| `target-aur2-03-distill` | "Regular exercise strengthens your heart…" | `~>'the main benefits of regular exercise'` |
| `target-aur2-04-jargon` | "The website is down because too many people…" | `:'the website returns 503 … overload'` |
| `target-aur2-05-define` | "An idempotent operation gives the same result…" | `:'idempotent'` (13c!) |
| `target-aur2-06-plainsentence` | "When you make a change, save a snapshot…" | `:'commit … so you can revert later'` |
| `target-aur2-07-firewall` | "A firewall is a network security system…" | `~>'what a firewall does'` (24c) |
| `target-aur2-08-legalese` | "You can cancel anytime and get a refund…" | `:'you may terminate … prorated refund'` |
| `target-aur2-09-analogy` | "A mutex is like a single bathroom key…" | `:'a mutex is a lock only one thread can hold'` |

### aur-1 · `?` questionify (how / what / why / should-I) + nested

| Example | Target | Expression |
|---|---|---|
| `target-aur1-01-tradeoff` | compression vs fidelity | seed + op |
| `target-aur1-02-polite` | shorthand → polite ask | `@'…'` |
| `target-aur1-03-question` | "How do I …?" | `'…'?` |
| `target-aur1-04-nested` | "How do I resolve a merge conflict in Git?" | `@('…'?)` |
| `target-aur1-05-compare` | "What is the difference between …?" | `'…'?` |
| `target-aur1-06-why` | "Why do my tests keep failing randomly?" | `'…'?` |
| `target-aur1-07-todo` | a polite multi-task request | `@&['…','…','…']` |
| `target-aur1-08-decision` | "Should I use REST or GraphQL …?" | `'…'?` |
| `target-aur1-09-howmuch` | "How much memory does a Rust Vec use?" | `'…'?` |
| `target-aur1-10-whatif` | a compound suggestion-question | `('a'&'b')?` |
| `target-aur1-11-when` | "When should you use an arc instead of a box?" | `'…'?` |

### msm-0 · `@` formalise (texting shorthand → professional; the 1-char floor)

| Example | Target | Expression |
|---|---|---|
| `target-msm0-01-formalize` | "Please let me know if you have any questions." | `@'lmk if any Qs'` (15c) |
| `target-msm0-02-microcompress` | short professional line | `@'omw'` |
| `target-msm0-03-signoff` | "Thank you very much." | `@'thx a ton'` |
| `target-msm0-04-brb` | "I will be back shortly." | `@'brb'` (3c) |
| `target-msm0-05-onechar` | "Understood." | `@'k'` (1c — the floor) |
| `target-msm0-06-fullreply` | a full 3-sentence reply | `@'thx, reviewed…, lgtm, merge…'` |
| `target-msm0-07-standup` | a full standup update | `@'ystd …, today …, blocked …'` |
| `target-msm0-08-status` | "…deployed to staging and ready for your review…" | `@'pushed fix to staging, ready to test'` |
| `target-msm0-09-review` | a review request (stance preserved) | `@'look at auth refactor when free…'` |
| `target-msm0-10-apology` | "Apologies for the delay…" | `@'sorry for the delay, got pulled into an incident…'` |
| `target-msm0-11-bug` | a bug report from telegraphic symptoms | `@'export button broken on safari…'` |

---

*Append new entries to the relevant table. Keep the per-agent dimension split so
the gallery stays legible: aur-1 cognition/stack/register, aur-2 corpus/coercion/
nested-logic, msm-0 conversation/ranges/interpolation; targets by mechanism.*
