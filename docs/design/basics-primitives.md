# Basics, det-coverage & arity — sigil/grammar design

**Status:** design (Harry, 2026-07-05, broadcast batch):
*"other basics like list indexing, sorting, comparison, ternaries, cond… make
sure every op has a det version… look at what arities/fixity can be loosened
safely (Haskell-ish; `>` won't work prefix but could use the stack)… `$_stdin`
first on the stack… `nlir 'expr'` == `nlir -e`."*

This note is the **operator-consolidator slice**: the sigils/naming for the new
primitives, and the **det-stub scheme** so `nlir test` can det-cover every op.
Impl lanes: eval/builtins + parser = msm-0; config entries + det realisations +
tests = aur-2/msm-1; QA audit + live-verify = aur-0; CLI ($_stdin-on-stack, bare
`nlir 'expr'`) = aur-2/msm-1. Input: aur-0's op-audit matrix.

---

## 1. The constraint: the glyph set is full

Taken single-char ASCII: `# ! & | ? ~ @ : > < Δ _ + * - / =` (+ `~> ~>?  **`
multi-char, `{} % $` structural, `^` messages). Free: **`\`** (splice reserve)
and **multibyte** (which lex for free, like `Δ`). So the new primitives must
**not** claim scarce ASCII glyphs. Three clean homes exist:

- **free 2-char ASCII combos** — the newest precedent: msm-2 just landed `++`
  (concat) + `//` (split) at a5b3373. Like `**`/`~>`, a 2-char combo of otherwise-
  taken chars is free real estate, and reads as a normal infix op. Best where a
  **conventional** 2-char spelling exists (`== != <= >=`).
- **word-builtins** dispatched at `%`-application, exactly like `$map`/`$fold`
  (`eval.rs` recognises `map`/`fold` when the context has no user binding). Zero
  glyphs; best for the non-binary-operator-shaped primitives (`$sort`, `$nth`,
  `$if`) and for comparisons whose glyph is already taken.
- **user-config glyph aliases** via `form:`/`builtin:` operators (bd-44c294): a
  user who wants `≤` binds it in their config. Opt-in, multibyte, their call.

So: **core primitives ship as free-2-char-ASCII where conventional, else
`$`-builtins; scarce single glyphs stay unspent, and prettier glyphs are a
user-config choice.**

---

## 2. Comparison — `== != <= >=` (2-char) + `$lt $gt` (strict)

`<`/`>` are **tighten/expand** text lenses (prefix). Comparison **cannot** reuse
them: an operator carries a single `fixity`, and the config's flat-namespace
no-shadowing rule (bd-44c294, already enforced) forbids a second `>` entry — so
"prefix `>` = expand, infix `>` = compare" is not expressible as two ops. And
there is **no equality op at all** today (aur-0 audit).

**Design** (all naturally deterministic — a free det win): use free 2-char ASCII
where a conventional spelling exists, and word-builtins only where the glyph is
taken:

| op | means | form | example |
|---|---|---|---|
| `==` | equal | 2-char infix | `2 == 2` → `true` |
| `!=` | not equal | 2-char infix | `2 != 3` → `true` |
| `<=` `>=` | ≤ / ≥ | 2-char infix | `3 <= 3` → `true` |
| `$lt` `$gt` | strict `<`/`>` (glyph taken) | `$`-builtin | `$gt%(5,3)` → `true` |

`== != <= >=` are universally-known + free (following msm-2's `++`/`//`). Only the
two strict comparisons fall back to word-builtins because their glyphs are spent
on tighten/expand. All ride `%`-application/infix + compose with the stack (§6)
for point-free use (`3 5 $gt`, `x 0 >=`). Multibyte aliases (`≤ ≠`) remain an
opt-in user-config choice.

## 3. List index & sort — `$nth`, `$sort`

- **index:** `$nth%(i, list)` → the i-th element (`$nth%(0,[a,b,c])` → `a`).
  A postfix `list[i]` sugar is possible later, but `$nth` is the glyph-free
  primary and consistent with the builtins. (`$0`/`$1` already read the *arg
  frame* positionally — distinct from indexing a list *value*.)
- **sort:** `$sort%list` → ascending; `$sort%(cmp, list)` optional custom order
  via a comparison form. Both deterministic.

## 4. Ternary / cond — `$if` (no `?:` collision)

`?`=question (postfix), `:`=simplify (prefix) — a `c ? a : b` ternary collides
head-on with both. **Design:** a builtin, `$if%(cond, then, else)` → `then` if
`cond` is truthy else `else`. Reuses `%`-application, zero glyphs, naturally det.
`cond`/`when`/`unless` can follow the same shape if wanted. (A user who wants a
`?`-ish glyph can bind one via bd-44c294.)

---

## 5. Det-stub scheme — every op testable in `--mode det`

Harry: *"every op has a det version even if it's just 'the opposite of arg', so
we can det-everything-in-test."* aur-0's audit: 8 ops are llm-only and error in
det mode — **`# : @ ~ >`** (text lenses) and **`Δ ~> ~>?`** (semantic). The rest
(`! & + - * / ** _ |`, and all of §2–4) are already det.

**Implementation seam:** add an optional **`det:`** realisation to an operator —
a form/builtin used **only in `--mode det`**, dispatched by the eval's
mode-selector (msm-0). This *reuses the bd-44c294 `form:`/`builtin:` machinery*:
a det-stub is just a form bound to the op for det mode. Clean, no new concept.

**Two stub shapes** (aur-0's flag — don't force one):

1. **Text lenses (`# @ ~ : >` `<`)** → a **literal-prefix** stub that is total,
   deterministic, and *shape-preserving* so the op's plumbing is exercised:
   `#X`→`"subject: X"`, `@X`→`"formal: X"`, `~X`→`"summary: X"`, `:X`→`"simple:
   X"`, `>X`→`"expanded: X"`, `<X`→`"tight: X"`. The det output need not be
   *semantically* right — only deterministic + total, so a chain like `@(~x)`
   runs end-to-end in det mode.
2. **Semantic ops (`Δ ~> ~>?`)** → **structure/bool** stubs, *not* text prefixes:
   - `~>` (implication, **bool**) → a deterministic boolean, e.g. substring/
     containment (`a ~> b` = `b ⊆ a` normalised) so `code ~> 'X'` stays a
     testable `true`/`false` in det mode — the whole point of `~>`'s type.
   - `Δ` (diff) → a deterministic structural line/word-diff.
   - `~>?` (derive) → a deterministic marker echo of its antecedent.

Keeping the two shapes distinct means det mode tests each op **at its real type**
(text vs bool vs diff), not a uniform string — which is what makes the coverage
meaningful rather than cosmetic.

---

## 6. Arity/fixity loosening — pull the missing operand from the stack

aur-0's audit: `? Δ ~> ~>?` error in **prefix** position (they're infix/postfix
only). Harry: loosen safely, *"`>` won't work prefix but could implicitly use the
stack."* The foundation exists — `Expr::StackIndex` + nullary-pop stack
consumption (bd-9aac32).

**Design intent** (parser lane = msm-0; sigil-lane note here): when an
infix/postfix op appears with a **missing operand**, pull it from the **stack
top** rather than erroring. `$_stdin` seeding the stack at position 0 (aur-2)
makes `… | nlir -e '?'` work — `?` finds its operand on the stack. This turns the
`$`-builtins of §2–4 concatenative: `3 5 $gt`, `[3,1,2] $sort`, point-free chains
without infix glyphs — the Haskell/Forth terseness Harry's after, *earned by the
stack, not by spending glyphs.* **Safety:** loosen only where the stack-pull is
unambiguous (a single missing operand, well-defined arity); test-driven per
aur-0. Ops whose prefix form already means something (`>`/`<` = expand/tighten)
are **not** loosened — their prefix slot is taken.

---

## 7. Summary

1. New primitives avoid scarce glyphs: **`== != <= >=`** (compare, free 2-char)
   + **`$lt $gt`** (strict, taken glyph) + **`$nth`** (index), **`$sort`**,
   **`$if`** (cond) as `$`-builtins. Prettier glyph aliases = opt-in user config
   (bd-44c294). Follows msm-2's `++`/`//` 2-char precedent.
2. **det-stub scheme** = an optional `det:` realisation per op (reuses
   form:/builtin:), in **two shapes**: text-prefix stubs for the 5 text lenses,
   bool/diff stubs for `~> Δ ~>?`. Everything else is already det.
3. **arity/fixity** loosens by **stack-pull** for missing operands (on the
   existing StackIndex/nullary-pop foundation); `$_stdin` seeds stack pos 0. The
   `$`-builtins go concatenative — terseness from the stack, not new glyphs.

Impl: eval/parser = msm-0, config + det realisations + tests = aur-2/msm-1, QA
live-verify = aur-0. This note = the sigil/naming + det-scheme design (aur-1).
