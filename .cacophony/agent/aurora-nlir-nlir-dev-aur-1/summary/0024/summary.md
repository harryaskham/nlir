# Session summary — golf #11 (FAQ entry) + target #09 (how-much question)

## What landed
- examples/golf-aur1-11-faq.sh — `'<doc>';[#$?,~$]`: push a doc once, peek twice →
  [#$? = question(subject) = the FAQ QUESTION, ~$ = summary = the ANSWER]. A full
  knowledge-base Q&A row from one paragraph. Combines stack-peek reuse (doc appears
  once) + auto-FAQ composition (#…? question-the-subject).
- examples/target-aur1-09-howmuch.sh — 5th `?` mood: 'how much memory does a rust vec
  use'? (37c) → "How much memory does a Rust Vec use?" (exact). ? palette now complete:
  how-do-I / what-is / why / should-I / how-much, all inferred from seed shape.

## Operator-takeaway
FAQ entry = one paragraph → its question + its answer, doc pushed once & peeked twice
(stack reuse + auto-FAQ). And ? now spans the full 5-mood interrogative palette.
