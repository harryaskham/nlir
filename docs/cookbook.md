# nlir cookbook — building real programs out of forms

The quote-eval forms (`{…}` quote, `%` apply, `$0 $1 …` arguments, `_N` repeat)
turn nlir from a one-shot transform into a small **functional language**. This
page is a worked catalogue of multi-layer programs you can build with them
**today**, every deterministic output verified with:

```sh
nlir --config config.example.yaml --mode det -e '<expr>'
```

If you are new to the forms, read the
[Forms & application](../README.md#forms--application--the-programmable-core)
section of the README first; this page is the "now build something with them"
follow-on.

> **The one-line mental model**
> `{ … }` is code-as-data (a *form*, inert until applied). `(` `)` is ordinary
> grouping. `%` **applies** a form to an argument frame, binding `$0 $1 …`.
> `=` **names** a value; `$name` **reads** it back. `_N` **repeats** a form.

---

## 1. Name a function, then reuse it

Bind a form to a name with `=`, then call it back with its **dollar-name**
`$name` and apply it with `%`:

```
f={$0+1};$f%5                         → 6
```

The gotcha that trips everyone: you call `$f%5`, **not** `f%5`. Bare `f` is not
the form — `$f` reads the form back out of context, and only a form can sit on
the left of `%`. (`f%5` errors with *"the left of `%` must be a {…} form"*.)

Two arguments come from a **frame** — a tuple `%(a,b)` or list `%[a,b]`:

```
add={$0+$1};$add%(2,3)                → 5
sq={$0*$0};$sq%5                      → 25
```

Arguments are themselves expressions, evaluated before binding:

```
{$0+$1}%(1+1,2*3)                     → 8
```

---

## 2. Compose and nest — chains many layers deep

A form's result is just a value, so you feed one call straight into another.
Read these inside-out, like ordinary function composition:

```
inc={$0+1};dbl={$0*2};$inc%($dbl%5)   → 11     # inc(dbl(5)) = inc(10)
sq={$0*$0};$sq%($sq%2)                → 16     # sq(sq(2)) = sq(4)
```

Deeper — a tree of calls, four layers:

```
add={$0+$1};$add%($add%(1,2),$add%(3,4))   → 10   # add(add(1,2), add(3,4))
```

Iterated composition by hand — `inc` applied three times:

```
inc={$0+1};sq={$0*$0};$sq%($inc%($inc%($inc%2)))   → 25   # sq(inc³(2)) = sq(5)
```

Mixed operators — a three-layer pipeline `dbl → inc → dbl`:

```
inc={$0+1};dbl={$0*2};$dbl%($inc%($dbl%3))   → 14   # dbl(inc(dbl(3)))
```

---

## 3. Repeat a form `N` times — `_N`

`_` is the repeat operator lifted from text to forms: `{form}_N` composes the
form with itself `N` times. Apply binds tighter than `_`, so parenthesise the
composition before `%`:

```
({$0+1}_3)%5                          → 8      # inc three times: 5→6→7→8
({$0*2}_4)%1                          → 16     # double four times: 1→2→4→8→16
```

On a **named** form, wrap the read in parens — `($f)_N`, not `$f_N` (see
[Gotchas](#gotchas): `$inc_5` lexes as one identifier `inc_5`):

```
inc={$0+1};(($inc)_10)%0              → 10     # count to ten
```

---

## 4. Flagship programs

These read like real little programs — all deterministic, all exact.

**Pythagorean sum of squares** — `sq(3) + sq(4)`:

```
sq={$0*$0};add={$0+$1};$add%($sq%3,$sq%4)    → 25
```

**A polynomial evaluator** — `x² + 2x + 1` at `x = 5`:

```
poly={($0*$0)+(2*$0)+1};$poly%5              → 36
```

**Two iterated pipelines, summed** — `dbl³(1) + dbl²(1)`:

```
dbl={$0*2};((($dbl)_3)%1)+((($dbl)_2)%1)     → 12
```

---

## 5. Coming soon — map/fold over a list

The one thing you **cannot** do yet is map a form over each element of a list.
`{$0+1}%[1,2,3]` is **not** a map — the list is an *argument frame*
(`$0=1, $1=2, $2=3`), so it returns `2`. Per-item map is the designed next
functional primitive (tracked in **bd-14af74**); today only the fixed `:`
(simplify) op maps per item. The intended shape (syntax pending a ruling):

```
$map%({$0*$0},[1,2,3])        → [1,4,9]     # NOT YET — bd-14af74
$fold%({$0+$1},[1,2,3,4])     → 10          # NOT YET — bd-14af74
```

This pairs with making **lists first-class results** — see the last gotcha.

---

## Gotchas

- **Call named forms with `$name`, not `name`.** `$f%5` works; `f%5` errors.
- **Repeat a named form with parens: `($f)_N`.** `$f_N` lexes as a single
  identifier `f_N` (underscore is an identifier char), giving *"unknown context
  key"*. Inline forms are fine: `({…}_N)`.
- **A bare list collapses to its last element.** `[1,4,9]` evaluates to `9`
  today — lists are only consumed by spreading ops (`&[a,b,c] ≡ a&b&c`), not
  yet surfaced as standalone values. First-class list results land with
  map/fold (bd-14af74).

---

## Beyond arithmetic — text pipelines (`--mode llm`)

The same forms compose over the language operators, where each step is a model
realisation. Drop `--mode det` to run these live against your configured model;
the operator lenses (`~` gist, `@` formal, `:` plain, `>` expand, `<` shorten,
`#` subject, `&` weave, `?` question) are the building blocks. See the
[showcase](../showcase/) for real captured outputs and
[POWERMOVES](../examples/POWERMOVES.md) for the curated one-liners.

A form lets you name a reusable **tone** or **transform** and apply it to
different inputs — for example a "make it a courteous one-liner" form, or a
"summarise then formalise" pipeline — the same `$name%input` shape as the
arithmetic examples above, but each layer is a language transform. Once
per-item map (bd-14af74) lands, the same forms will run over a whole list of
messages at once.
