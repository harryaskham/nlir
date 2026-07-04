# nlir TRAINS — reusable multi-op pipelines (aur-2 exploration)

Prompted by Harry/sgu24-app: "imagine longer trains of nlir exprs that do useful things
in repeatable ways ... do we have function abstraction or lambda?" — with REAL example
text, not toys.

## What a "train" is today
nlir composes operators by NESTING: `~:>x` = `~(:(> x))`. Each op consumes the previous
op's result, so it's already **point-free per stage** — the only explicit argument is the
seed `x`. A train is just a multi-op pipeline that does a useful job. Order matters and the
LAST op dominates the output shape (cf. aur-1 #104: `~>x`≠`>~x`).

## Useful trains (all verified, claude-sonnet-5)

### 1. THE ELEVATOR PITCH — `~:>x` (expand → simplify → distil)
Flesh a terse idea out (`>`), make it plain (`:`), then boil to one line (`~`).

    ~>'a CLI that transpiles a terse sigil shorthand into fluent English via a configurable stack machine'
    -> "A command-line program that uses a configurable stack-based parser to translate
        symbolic shorthand code into clear, plain English sentences."

A real pitch from a rough feature note — repeatable over ANY terse idea.

### 2. THE DE-RAMBLE — `@~x` (distil → formalise)
Summarise a rambling vent (`~`), then formalise it (`@`) into a sendable official line.

    @~'ok so basically the deploy keeps breaking because nobody runs the tests before pushing and its getting really annoying honestly'
    -> "Deployments repeatedly fail because tests are not executed prior to code being pushed."

A one-line "make this professional" pipeline — repeatable over any rant.

### 3. THE PLAIN DEEP-DIVE — `:>~x` (distil → expand → simplify)
Find the core (`~`), expand it (`>`), render it plain (`:`) — a focused ELI5 treatment
(order-sensitive; ending on `:` makes it plain but can start mid-thought — `~:>` is tighter
for a headline, `:>~` for a body).

## THE GAP (the lambda Harry asks about)
These trains are RE-TYPED every time. nlir has **value abstraction** (`k=v;$k` binds a
VALUE) but NO **function abstraction**: you cannot bind a TRANSFORM and reapply it —
`pitch := ~:>` then `pitch 'idea1'; pitch 'idea2'` — nor write a point-free APL/J-style
TRAIN as a first-class value `(~:>)`. Missing pieces:
  - a **lambda / define** (name a composed transform, apply to many inputs), and
  - a **compose operator** (make `(~:>)` a reusable, first-class pipeline).
With those, a train becomes a named tool you point at real context (`pitch ^-1`,
`derampl ^_-1`) instead of a phrase you retype. Handed to the operator-algebra design
(aur-1's consolidation) as the natural home; this doc proves the trains are useful TODAY
and pins exactly where abstraction would pay off.
