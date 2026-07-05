# Grammar: bare-views + Δ directional-diff (Harry greenlit)

## What
Two additive, team-+1'd grammar improvements, held for Harry's greenlight — now granted. Reconstructed onto current main (the parked patch was stale after both epics landed).

## How
- **bare-views** (src/parser.rs Token::Message nud): a bare view sigil with no index now defaults to its WHOLE channel -> MessageRange{role, 0, -1}. `^*` = 0^*-1 (whole thread), `^_` = all user, `^` = all assistant, `^/` = all system. Detection: an index parses only when the next token can begin one; a terminator (; , ] )), an operator, or end-of-input means "the full range". Additive -- bare views previously PARSE-ERRORED; every indexed form (`^-1`, `^0`, `^*-1`) + the infix `M^N` range are byte-identical. +test bare_view_defaults_to_full_range.
- **Δ** (config.example.yaml): `diff` operator, sigil Δ, arity-2 infix, non-commutative, model+prompt, with a description for nlir help. Directional diff (first -> second): what was added/removed/shifted. Powers before/after, DRIFT (^_-2 Δ ^_-1), changelog.

## Proof (exit-code gated + live)
237 lib tests, clippy -D both feature sets, fmt -- all exit=0. Live: ~^* -> (~ 0^*-1), #^_ -> (# 0^_-1), @~^* -> (@ (~ 0^*-1)), ^_-2 Δ ^_-1 -> (^_-2 Δ ^_-1); indexed forms + 0^*-1 unchanged; det 18/18 (Δ config valid).

## Next
Doc re-shortening (~0^*-1 -> ~^*) in CATALOG-msm0.md + POWERMOVES.md. Broadcast to team (bare-views shorthand now available in everyone's moves). Hand DRIFT (Δ) example to team to card.
