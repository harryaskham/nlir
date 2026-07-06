# A composable core that forms trains (APL/J for nlir)

Operator directive (Harry, 2026-07-05): study the interesting primitives from
APL / J and friends; find the gaps; design a **composable core** for nlir's
config/core that lets a *seed of a few words* + lots of composed operations
express powerful concepts — driven by **writing increasingly complex mixed
text+det programs** and fleshing out the lib from what they need. *"Don't add
every function in every language — focus on a composable core that can form
**trains**."* Reworking operators to reclaim namespace is allowed; keep examples
in sync.

This is the shared anchor doc. One file, everyone appends their lane:
- **Exemplar programs + filter/scan/zip specs** — msm-2 (this seed).
- **Trains + category-theory design** — msm-1 (§4, dropped in from `nlir-trains-design`).
- **Train grammar / sigils** — aur-1 (§5).
- **Gap ranking + verification** — aur-0 (§6).
- **Impl** — msm-0 (eval/parser/stack), aur-2 (config/builtins). Not in this doc.

---

## 1. What the composable core already is (inventory)

nlir is further along than it looks. The pieces already present compose into
real point-ish-free programs:

| Piece | Form | Role (APL/J analogue) |
|---|---|---|
| quote | `{ … }` | a form = code-as-data (a gerund / verb noun) |
| apply | `{f}%x` | apply a form to an argument (`∘`-ish when nested) |
| positional | `$0 $1 …` | operand refs inside a form (⍺ ⍵ / x y) |
| map | `$map%({f}, xs)` | each `¨` |
| fold | `$fold%({g}, xs)` | reduce `/` |
| filter | `$filter%({p}, xs)` | where/compress (landed @d7f6f6c, bd-fd3a37) |
| scan | `$scan%({g}, xs)` | running-fold `\` (landed @d7f6f6c) |
| do-N | `({f}_N)%x` | power `⍣N` (compose a form N times) |
| glyph-ops | `form:`/`builtin:` (bd-44c294) | name a form/builtin as a one-glyph verb (`□`, `⇑`, `↦`, `⊘`) |
| numeric reduce | `+ - * / **` | scalar dyads |
| **string** | `++` concat, `//` split (bd-c833a8) | catenate `,` / split |
| branch | `$if%(c,t,e)` | short-circuit ternary (@f2a50d5) |
| index | `$nth%(i,xs)` | pick / index; `-1` = last (@f2a50d5, negatives @4499f58) |
| sort | `$sort%xs` | grade up `⍋` (@f2a50d5) |
| compare | `== != <= >=` | dyadic predicates → Bool (@2521bf1) |
| trains | `(f g)` atop, `(f g h)` fork | tacit composition (@d903823, @bbe15c2) |

Composition today is **explicit**: you nest applies or name forms and thread the
argument (`$f%($g%x)`). That works — the gap is making it **point-free** (§3.1).

---

## 2. Verified exemplar programs (runnable, deterministic)

All run today with `nlir -e '…' --config config.example.yaml --mode det`. These
are the "seed of a few glyphs → real program" targets, kept green as a
regression surface.

```text
# P1 — map-then-fold: tag each, then catenate.  (fold ∘ map)
$fold%({$0++$1}, $map%({$0++"!"}, ["a","b","c"]))            => a!b!c!

# P2 — split → map-double → fold-join: a full pipeline over a parsed string.
_sep=\ ;$fold%({$0++","++$1}, $map%({$0++$0}, "x,y,z"//","))  => xx,yy,zz

# P3 — do-N power: double a string 3× (×8).  (⍣N)
({$0++$0}_3)%"ab"                                             => abababababababab

# P4 — map over a split: transform each field.
_sep=\ ;$map%({$0++"-done"}, "t1,t2"//",")                    => t1-done t2-done

# P5 — WORD COUNT as (sum ∘ map(const 1) ∘ split): length = +/ over 1¨.
$fold%({$0+$1}, $map%({1}, 'the cat sat on the mat'//' '))    => 6

# P6 — per-word char count: length as a reusable SUB-PROGRAM, mapped over words.
_sep=\ ;$map%({$fold%({$0+$1}, $map%({1}, $0//""))}, "the cat sat"//" ")  => 3 3 3

# P7 — TRAINS (atop, landed @d903823): compose lenses point-free, no $0.
(: ~ @)%"hi"                                                  => simple: summary: formal: hi

# P8 — TRAINS (fork, @bbe15c2): two lenses on one input, mapped over a split.
_sep=" || ";$map%({(# & ~)%$0}, "a,b"//",")  => subject: a and summary: a || subject: b and summary: b

# P9 — COUNT how many pass a test (correctness-gate flagship, @2521bf1): compare→map→fold.
$fold%({$0+$1}, $map%({$0>=5}, [3,7,2,9]))                    => 2

# P10 — MAX / MIN as order statistics for FREE (@f2a50d5): last / first of a sort.
$nth%(-1, $sort%[3,1,4,1,5])                                  => 5    (max)
$nth%(0,  $sort%[3,1,4,1,5])                                  => 1    (min)

# P11 — BRANCH on a det comparison (@f2a50d5 + @2521bf1): deterministic control flow.
$if%(3<=5, yes, no)                                           => yes
```

P5 is the flagship: **length is not a primitive** — it *falls out* of
`split → map(→1) → fold(+)`. That is the whole thesis: a composable core makes
"functions" emerge from a handful of adverbs, so we don't hard-code each one.

### Mixed text+det target (needs filter, §3.2)

The programs get their power when the *structure* is det and the *steps* are
fuzzy. The canonical target:

```text
# "urgent digest": keep the urgent messages, gist each, weave into one summary.
$fold%({~($0 & $1)}, $map%({~$0}, $filter%({$0 ~> 'urgent'}, msgs)))
#        \_ weave gists _/         \_ gist each _/  \_ SELECT urgent _/
```

det scaffold (`filter`/`map`/`fold`) + fuzzy per-step (`~>` classify, `~` gist,
`&` weave). The det scaffold works now (**filter landed @d7f6f6c**); the `~>`
classify awaits its det-bool stub (aur-0's semantic-op category, §3.2).

---

## 3. Gaps this seeds (msm-2 spec; ranking in §6, impl msm-0/aur-2)

Ranked by aur-0: **trains #1, filter #2, scan #3.** During this loop the whole
core LANDED: **filter + scan** @d7f6f6c, **trains** (atop + fork)
@d903823/@bbe15c2, and the **basics** — `$if`/`$nth`/`$sort` @f2a50d5, signed
literals @4499f58, **comparisons** `== != <= >=` @2521bf1 — so the deterministic
control-flow backbone is complete (the count idiom, §2 P9). **Remaining
follow-ups:** tacit application without `%` (§3.1), the `~>` det-bool stub
(§3.2), a right-associative `%` (unanimous, awaiting greenlight), and **zip**
(§3.4, a candidate).

### 3.1 Trains / point-free composition (#1) — LANDED @d903823 + @bbe15c2

The category-theory core: compose lenses *without spelling `$0`*. aur-1's grammar
(§5): a **parser desugar** on operator-only parenthesised groups, on msm-0's
stack-implicit foundation — zero new glyphs, applied via `%`.

- **ATOP works** (verified): `(~ @)%"thanks"` → `summary: formal: thanks`;
  `(: ~ @)%"hi"` → `simple: summary: formal: hi` (compose right-to-left).
- **FORK works with an INFIX combiner** (verified): `(# Δ ~)%"hello"` →
  `diff: subject: hello -> summary: hello` (two lenses on one input, combined).
- **FORK with a MIXFIX combiner** — FIXED @bbe15c2 (bd-57f470): the headline
  `(# & ~)%"hello world"` → `subject: hello world and summary: hello world`
  (subject AND gist — two lenses on one input); `(: & #)%"fn add"` =
  explain-and-name. The fork now accepts `&`/`|` (mixfix) as the combiner, so
  Harry's #1 (two lenses woven with "and"/"or") is live. The mixfix-rejection
  diagnosis was found independently by aur-0 + msm-1 + msm-2.

Follow-up (msm-0): tacit application without `%` (juxtaposition `(# & ~)doc`).
Full design §4 (msm-1) + §5 (aur-1). Biggest unlock: forks multiply every lens.

### 3.2 `$filter` / where — LANDED @d7f6f6c

The missing **select** of map/filter/fold — now landed (msm-0/aur-2, bd-fd3a37):

```text
$filter%({pred}, xs)  — keep xs[i] where pred(xs[i]) is truthy → a List.
```

- Numeric + bool truthiness works (@9ea893e): `$filter%({$0}, [1,0,2,0,3])` →
  `[1,2,3]` (0/empty falsy, nonzero truthy); filter-local, global coercion stays
  strict. Bool literals too: `$filter%({$0}, [true,false,true])` → `[true,true]`.
  The trinity: `$fold%({$0+$1}, $map%({$0*$0}, $filter%({$0}, [1,2,3])))` → `14`.
- mixed example: `$filter%({$0 ~> 'urgent'}, msgs)` → the urgent subset (awaits
  the `~>` det-bool stub, aur-0's semantic-op category).

Completes the functional trinity: the correctness-gate can now **select** the
passing set, not just count it.

### 3.3 `$scan` / running-fold — LANDED @d7f6f6c

Fold that keeps every intermediate → a List (`\` in APL/J), landed alongside
filter:

```text
$scan%({g}, xs)  — [x0, g(x0,x1), g(g(x0,x1),x2), …]  (running-fold)
```

- `$scan%({$0+$1}, [1,2,3,4])` → `[1,3,6,10]`; composes:
  `$scan%({$0+$1}, $map%({$0*$0}, [1,2,3,4]))` → `[1,5,14,30]` (running
  sum-of-squares).
- Unlocks running consensus / cumulative / progressive-refinement programs
  (fold a list of views into a *running* consensus, not just the final one).

### 3.4 `$zip` / pairwise (candidate)

Combine two lists elementwise with a 2-arg form → a List. Enables tabular /
"align these two columns" programs. Lower priority than filter/scan; listed so
the adverb family (map/filter/fold/scan/zip) is complete on paper.

---

## 4. Trains & category-theory design (msm-1)

**The core is a tiny algebra.** nlir operators are morphisms over text/number
values, and the composable core is their algebra:

- **map** = functor — apply a form to each element, structure-preserving.
- **fold** = catamorphism — collapse a list with a 2-arg form.
- **atop** `(f g)x = f(g x)` = composition of morphisms.
- **fork** `(f g h)x = (f x) g (h x)` = parallel application then combine — run
  TWO lenses on ONE input, merge with a third. **The fork is the key new power**
  (product-then-merge): it multiplies every lens we already have.

This is the array-language (J/APL) insight: rich behaviour from algebraic
composition, not variable-heavy plumbing — exactly Harry's "seed of a few words
+ lots of composed ops / cat-theory structure".

**Point-free targets** (need aur-1's train grammar, §5 — zero new glyphs):
- "subject AND gist": `(# & ~)x` = `#x & ~x` (fork: two lenses, one input)
- "gist, formal, woven": `(~ & @)x` = `(~x) & (@x)`
- "concepts then simplify each": `(#* …)doc` — extract-then-map, tacit

Also verified today (det): sum `$fold%({$0+$1},[1,2,3,4,5])` → 15; **4!**
`$fold%({$0*$1}, $map%({$0+1}, [1,2,3,4]))` → 120; squares
`$map%({$0*$0}, [1,2,3,4,5])` → 1/4/9/16/25. Downstream (msm-1): as
trains/filter/scan land, these exemplars become verified cookbook entries +
det-test coverage.

## 5. Train grammar / sigils (aur-1)

A parenthesised group of operators with **no operands** is a TRAIN — a tacit
(point-free) function. Today it's a parse error (`(~ @)'thx'` → "unexpected token
RParen"), so trains fill currently-**error** syntax: a new parse rule, **zero
namespace cost, no operator rework**. A train applied to `x` **desugars to a
form**, so it rides the existing `{…}%x` machinery + msm-0's stack-implicit
foundation — the eval core is untouched.

**Two desugars, chosen by the arms' fixity (parser-directed):**

1. **Unary chain** — all-prefix lenses → ATOP compose, right-to-left:
   `(f g h)x ≡ f(g(h(x)))` → `{f(g(h($0)))}`. Verified: `{~(@$0)}%'thx'` =
   distil∘formal, so `(~ @)` ≡ that; `(~ > @)` = the steelman ⇑, tacit.
2. **Fork** — an INFIX op present as the combiner → both prefix lenses run on the
   SAME `x`, combined by the infix: `(f g h)x ≡ (f x) g (h x)` →
   `{(f $0) g (h $0)}`. Verified: `{(~$0)&(@$0)}%'…'` = gist & formal on one
   input, so `(~ & @)` ≡ that.

Longer trains fold right per J. **Detection (msm-0's parser):** all-prefix →
atop-chain; infix present → fork (infix = combiner `g`, prefix runs = `f`/`h` on
the shared `$0`). **Parser subtlety (flagged for msm-0):** train arms may be
parenthesised sub-exprs, not only bare ops — e.g. `(~ & (~>'production-ready'))`.

**Zero-cost:** the only new thing is the parse rule turning operator-only groups
into forms; forms + `%` + stack-implicit already evaluate them. No new sigil, no
eval rewrite. An explicit atop glyph `∘` would be a *separate optional* multibyte
alias; the parenthesised train is the zero-cost primary. `\` (splice) untouched.

**Fork payoff (multiplies every lens):**
- `(# & ~)x` = subject & gist (topic + summary in one).
- `(~ & @)x` = casual-gist & formal — two registers of one input.
- `(: & #)code` = explain-AND-name a snippet in 4 glyphs.
- `(#* $map:)doc` = extract-concepts-then-explain-each (fork feeding map).
- review-pipe → `(~ & (~>'production-ready'))$_stdin` = gist AND the
  production-ready verdict, point-free.

## 6. Gap ranking + verification (aur-0)

<!-- anchor: aur-0's ranked gap matrix + the standing verify gate (det-skeleton
+ llm) for every exemplar program. -->

Current ranking: 1) trains/point-free, 2) filter, 3) scan. Verified today:
glyph-op nesting green; P1–P5 above green; the compose trinity (map/filter/fold)
+ scan + trains = the full functional + point-free core.

---

## 7. Namespace-rework notes

Reclaiming glyphs is allowed (Harry) — record any op reworks here with the
example-sync checklist so `config.example.yaml` + docs stay green. None yet;
trains cost **zero** new glyphs (a parse rule), so the near-term additions
(`$filter`/`$scan`/`$zip`) are word-builtins alongside `$map`/`$fold` and need
no reclamation.
