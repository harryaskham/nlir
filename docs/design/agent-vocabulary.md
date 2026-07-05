# Minimal nlir for coding-agent instructions

**Status:** design / vocabulary exploration (Harry, 2026-07-05:
*"look at the kinds of things one says to a coding agent, and work out how, in
context, one could minimally express them"*).

Goal: take the things people actually say to a coding agent and find the
**tersest faithful nlir** for each — then surface the **new concepts** the
current operator set is missing. This is the language-design counterpart to the
[cookbook](../cookbook.md) (which shows what the forms can already do).

---

## 1. What you operate *on* — the context handles

nlir instructions are terse because the **subject is usually implicit** — it's
already in context. Three handles supply it:

| handle | is | example |
|---|---|---|
| `^-1` | the last assistant message; `^_-1` last user, `^*` all, ranges `(a)^(b)` | `~^-1` — gist the last reply |
| `$_stdin` | stdin — a diff, a file, an error paste (piped in) | `~$_stdin` — gist the piped diff |
| `$k` | a named value read back from context | `$err` — the error you stored |

So "summarise **this**" is just `~^-1` or `~$_stdin` — the operator, pointed at the
ambient subject. That implicit-subject economy is the whole reason a coding-agent
instruction can collapse to one or two glyphs.

---

## 2. Catalogue — common asks → tersest nlir

Deterministic where marked; the rest are single-model-call lenses (`--mode llm`).

| You say… | nlir | how |
|---|---|---|
| "summarise this / TL;DR" | `~^-1` | gist |
| "give me the point, keep the numbers" | `<^-1` | tighten (lossless, vs `~` lossy) |
| "explain / expand on this" | `>^-1` | expand |
| "explain it simply / de-jargon" | `:^-1` | simplify |
| "make it formal / professional" | `@^-1` | formal |
| "what's this about? (one label)" | `#^-1` | subject |
| "what changed from A to B" | `A Δ B` | directional diff |
| "turn this into a question" | `^-1?` | question |
| "what does this imply / what follows" | `~>?^-1` | derive the implication |
| "does A imply B? (yes/no)" | `A~>B` | implication check |
| "combine these into one statement" | `&[a,b,c]` | weave |
| "give me the options / alternatives" | `\|[a,b,c]` | or-choice |
| "summarise then make it formal" | `@(~^-1)` | compose lenses |
| "steelman this" | `~(>@^-1)` | expand→formalise→distil (a form) |
| "summarise each of these" | `$map%({~$0}, [<list>])` | map a lens per item |
| "distil these views to a consensus" | `$fold%({~($0&$1)}, [<views>])` | fold weave+gist |
| "count the yeses" | `$fold%({$0+$1}, $map%({$0~>'affirmative'}, [<answers>]))` | classify-then-count |

Named/glyph macros (once **bd-44c294** lands `form:`/`builtin:` operators) turn
the frequent ones into your own vocabulary: `⇑ = {~(>@$0)}` (steelman),
`↦ = builtin map`, so `~↦[notes]` summarises each note in three glyphs.

### 2b. Coding-pipe idioms (via `$_stdin`)

Where the subject is piped in (a diff, code, an error), the same lenses apply to
`$_stdin`. Verified terse forms from the coding-pipe lane (aur-0/aur-2/aur-1):

| You say… | nlir | how |
|---|---|---|
| "summarise this PR / diff" | `git diff \| nlir -e '[#$_stdin,~$_stdin]'` | subject + gist of the diff |
| "review this code" | `<code> \| nlir -e '@&[~$_stdin,‹points›]'` | formal weave of gist + review points |
| "what's the likely fix?" | `<err> \| nlir -e '~(>"the most likely fix for: $_stdin")'` | expand a fix hypothesis, then distil |
| "explain this code" | `<code> \| nlir -e ':$_stdin'` | plain-language explanation (verified: catches an `add` that subtracts) |
| "name this fn/var" | `<code> \| nlir -e '#$_stdin'` | the subject/name |
| "is this correct?" | `<code> \| nlir -e '$_stdin ~> "correctly does X"'` | → **bool** assertion (verified `false` on a buggy `add`) — the faithful yes/no form §3b notes |

**The correctness-gate** (the coding instance of the det+llm flagship — aur-0-verified live): map a `~>`-check over a module's functions and fold the pass/fails:

```
$fold%({$0+$1}, $map%({$0 ~> "is a correct implementation of its name"}, [fn1, fn2, fn3])) -> 2
```

→ the per-function correctness vector is `[true, false, true]` (catches the broken one), summed = "2 of 3 correct". The LLM judges each function, deterministic `+` counts. Card pending.

The exhaustive coding-idiom catalogue + showcase cards live in the coding-pipe
lane (aur-0 cards/cookbook, aur-2 POWERMOVES); this doc keeps a representative
set and focuses on the *design gaps* below.

---

## 3. The gaps — new concepts we need

The catalogue above stops where the operator set does. The instructions that
*don't* yet have a minimal form point at the primitives to add.

### 3a. Multi-concept extraction — a `#` that returns a **list** (Harry's flag)

`#` gives **one** subject. But a huge fraction of coding-agent asks are
"pull out the **several** things here":

- "list the risks / edge cases / TODOs in this"
- "what are the key concepts in this design?"
- "break this error down into the distinct failures"

There is no operator for *text → list of concepts*. It's the structural inverse
of `#` (which folds a list → one category), and it's the **missing feeder for
map/fold** — once you can extract a list, the whole functional layer applies:

```
concepts^-1                       -> [concept1, concept2, concept3]   (NEW)
$map%({>$0}, concepts^-1)         -> expand each concept
$map%({:$0}, concepts^-1)         -> plain-language each risk
$fold%({~($0&$1)}, concepts^-1)   -> distil the concepts to a theme
```

Proposal: a prefix operator (name `concepts`, glyph TBD — e.g. `#*` as a
suffixed sibling of `#`, or a Unicode glyph via bd-44c294) that realises to a
**list** of short noun phrases. Arity 1, `result: list`. It pairs with map/fold
so cleanly that it's arguably the single highest-leverage addition on this page.
Open design Qs: how many items (a `_n` cap? model-chosen?), and dedupe/ordering.

### 3b. Assess / critique — a judgement lens

"is this correct?", "what's wrong with this?", "review this" have no faithful
minimal form. `~>` gives a boolean implication and `?` makes a question, but
there's no "evaluate and tell me the problems" lens. Candidate: a `critique` /
`assess` operator (text → the salient objections/issues), which composes with
3a — `concepts` the issues, then map a fix-suggestion form over each.

### 3c. Code-shaped transforms

"refactor for clarity", "add a test", "make it robust" are code→code, not
text→text. These likely stay as `command:`/`prompt:` operators (or forms bound to
those via bd-44c294) rather than core lenses — noting the boundary so the core
vocabulary stays about *thought*, and code-mutation rides the operator table's
existing escape hatches.

---

## 4. The UX half — partial results while you iterate

Harry: *"better partial result display in e.g. pi would let us quickly iterate on
chains of thought."* The vocabulary only pays off if you can **watch a chain
resolve**. That's already in flight:

- `nlir step` streams each reduction live (**bd-89eb89**, CLI leg landed) — you
  see `~(>@^-1)` unfold one realisation at a time.
- The TUI live det-preview (**bd-970e05**) shows the result-so-far as you type.
- The **pi plugin** is the place to close this: as you build a `|`-prefixed
  chain, show the intermediate realisations inline (each `$map`/fold/lens step as
  it resolves) so you tune the chain without re-running it whole. Tracks the same
  streaming API as the CLI/TUI legs.

---

## 5. Summary — the shortlist

1. **Multi-concept extraction** (`concepts`, text → list) — the highest-leverage
   gap; unlocks map/fold over extracted ideas (3a).
2. **Assess/critique lens** — the missing "what's wrong here" (3b).
3. **Glyph/form operators** (bd-44c294) — let frequent chains become a personal
   terse vocabulary.
4. **Partial-result display in pi** — makes iterating on chains-of-thought fast
   (4).

Items 3–4 are already moving (bd-44c294, bd-89eb89, bd-970e05). Items 1–2 are the
new language concepts this exploration surfaces.

---

## 6. Sigil & grammar design for the new operator kinds (aur-1)

The three additions above (multi-extract, `form:` ops, `builtin:` ops) all touch
the **operator sigil namespace**, which is nearly full — `{}`, `%`, and every lens
are taken; `\` is the one free ASCII single-char (earmarked for macro-splice). One
coherent allocation, so the grammar doesn't fork:

### Multi-extract → `#*` (resolves 3a's glyph Q)

Recommend **`#*`** for text→list-of-concepts, not a fresh glyph:

- `*` is already the **"all"** modifier (`^*` = all messages; `(a)^(b)` ranges), so
  `#*` reads as "**all** the subjects" — the plural of `#` (one subject) — learnable
  from a pattern users already know. **Zero new glyph spent.**
- A word-builtin **`$concepts`** can co-exist as the spelled-out form (like `$map`/
  `$fold` alongside a future glyph), for configs/users who prefer words.
- Rejected: `##` (doubling reads as "subject-of-subject", wrong sense); a Unicode
  glyph (spends novelty for no readability gain over `#*`).

**Count / dedupe (msm-1's open Q):** default **model-chosen** — the common ask
("the risks", "the concepts") has no fixed N. Do **not** overload `_N` for a cap:
`_N` already means form-compose / do-N (`({f}_3)`), so a `#*_3` cap would collide.
If a cap is later wanted, pass it as an explicit operand form rather than a suffix;
defer until there's real demand. Ordering: salience-first, de-duplicated, plain
noun-phrase list, so `$map`/`$fold` over it stays clean.

### `form:` / `builtin:` operator sigils (bd-44c294)

The **mechanism needs no reserved glyph** — an `op:` is whatever the *user's config*
names it:

- **Word-names** are the baseline (`steelman`, `mapop`) — same class as `$map`, no
  ASCII pressure.
- **Multibyte glyphs** are free to spend (`⇑`, `↦`, `⊘`) — they don't touch the
  ASCII single-char scarcity (`Δ` already lexes this way).
- Keep **`\`** unspent (macro-splice reserve).

**Collision rule (the one hard constraint):** the config validator must reject an
`op:` that shadows a built-in operator or another config op — one flat namespace,
first-definition-or-error, so a user glyph can't silently reassign `~` or `%`.
Arity is inferrable from the form's max `$N` (`{$0+$1}` ⇒ arity 2); `form:`/`builtin:`
validation should cross-check that against any declared `arity:`.

**Net:** one new ASCII sigil across all three (`#*`, itself a *reuse* of `*`), plus
user-config word/multibyte ops that stay off the scarce core set. The grammar stays
coherent and the `\` splice reserve is preserved.
