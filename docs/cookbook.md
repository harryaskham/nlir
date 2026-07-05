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

## 5. Map and fold over a list — `$map` / `$fold`

`$map` applies a form to **each** element of a list and gives back the list of
results; `$fold` reduces a list to one value with a two-argument form. Both are
builtin forms, called through the usual apply — the primitive that makes
list-processing programs click (bd-14af74):

```
$map%({$0*$0},[1,2,3])            -> 1 / 4 / 9      (square each)
$map%({$0+1},[10,20,30])          -> 11 / 21 / 31   (increment each)
$fold%({$0+$1},[1,2,3,4])         -> 10             (sum)
$fold%({$0*$1},[1,2,3,4])         -> 24             (product)
```

Named forms work as the mapper too:

```
sq={$0*$0};$map%($sq,[1,2,3])     -> 1 / 4 / 9
```

And they compose — real **map-reduce** and nested higher-order programs:

```
inc={$0+1};$fold%({$0+$1},$map%($inc,[1,2,3]))       -> 9      (increment each, then sum)
$fold%({$0+$1},$map%({$0*$0},[1,2,3]))               -> 14     (sum of squares — fold∘map)
$map%({$fold%({$0+$1},$0)},[[1,2],[3,4]])            -> 3 / 7  (sum each sub-list — a mapper that folds)
```

Because the mapping form can be *any* form, in `--mode llm` you run a language
transform over every item at once — `$map%({~$0},[…])` distils each element,
`$map%({@$0},[…])` formalises each. That's the payoff: one expression over a
whole list.

Don't confuse `$map` with the argument frame: `{$0+1}%[1,2,3]` is **not** a map —
there the list binds as arguments (`$0=1, $1=2, $2=3`), returning `2`. Use
`$map%(form,list)` for per-item. (`map`/`fold` are reserved only in apply
position — a context key you define named `map` still wins.) You can also still
build a list by hand — `sq={$0*$0};[$sq%1,$sq%2,$sq%3]` -> `1 / 4 / 9` — when the
elements aren't uniform.

---

## Gotchas

- **Call named forms with `$name`, not `name`.** `$f%5` works; `f%5` errors.
- **Repeat a named form with parens: `($f)_N`.** `$f_N` lexes as a single
  identifier `f_N` (underscore is an identifier char), giving *"unknown context
  key"*. Inline forms are fine: `({…}_N)`.
- **Lists are first-class and render sep-joined.** `[1,4,9]` -> `1` / `4` / `9`
  (three lines), *not* `9`. The `nlir: EXPR -> RESULT` summary prints a
  multi-line result inline, so `… | tail -1` grabs only the last line — use
  `--quiet` to see the clean list.

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
