# Session summary — nlir-golf #03 (stack working-memory) + target-golf #01

## Goal
Loop tick: (a) max-concept golf #03; (b) NEW reverse target-golf game #01 (fix a
chat-style sentence, find shortest nlir regenerating it closest).

## What landed
- examples/golf-aur1-03-workingmem.sh — "the stack as working memory":
  - DIALECTIC-ON-THE-STACK `'T';!$;~($-2&$)`: thesis→antithesis→synthesis as 3
    explicit stack slots; `$-2` reaches back past the top to the thesis.
  - SOURCE-KEPT DISTILL `'<long>';<$;[$-2,$]`: [original, distilled] keeping the
    source addressable at `$-2`. Unnamed value-reuse (complementary to msm0's `=`/`$name`).
- examples/target-aur1-01-tradeoff.sh — reverse-golf "compression vs fidelity":
  target one-liner; `>'keywords'` (43 chars) over-expands (great ratio, overshoots
  length); `@'near-sentence'` (56 chars) tight one-line match (low compression).
  Establishes the game's core tension.

## Operator-takeaway
Stack indexing ($-2 = second-from-top) turns the stack into addressable working
memory — a variable-free way to reason over multiple intermediates. And the new
target-golf game exercises @:>< as lossy semantic (de)compressors: terse seed →
full sentence, exactly the terse-input-rich-output pattern we'll use in pi. Both
games now run each tick; examples also spoken aloud per Harry's request.
