# Session summary — nlir output: --dry-run assembled-prompts preview (bd-256baa)

## Goal

Complete `--dry-run` (SPEC §Modes: "DAG + assembled prompts, no calls"): in llm
mode, preview the model + the prompt that WOULD be sent for each llm-realised
operator, without making any call.

## Bead(s)

- `bd-256baa` — Output: --dry-run assembled-prompts preview (parent epic bd-6cdfee)

## Before state

- `--dry-run` printed only the DAG; the assembled-prompts half was deferred (Mode::Llm realisation had not landed when the follow-on was filed).
- Failing tests: none. 199 unit tests.

## After state

- Failing tests: none. 201 unit tests pass; clippy `-D warnings` clean; `cargo fmt --check` clean. Verified end-to-end + in the integration smoke.
- New additive `llm::realise_llm_preview(model, prompt, operands, config, cli_model, env)` mirrors `realise_llm`'s assembly (resolve_model → substitute_operands → resolve_prompt_fragments → assemble_nlir_vars) but RENDERS the model + assembled prompt/messages instead of calling — no network/subprocess.
- `run_dry_run` now walks the parsed `Program` in llm mode (`preview_llm_prompts`/`collect_llm_previews`): for each `Apply` whose operator is llm-realised (`command.is_none() && reduce.is_none() && prompt.is_some()`), it prints `` `op` -> <model + assembled prompt> ``. Operands are shown exactly for literals; a nested subcall is rendered as its source expression in `«…»` (its true value is the child's result at eval time — the only approximation, since fully evaluating nested operands needs the eval walk). Prints "no llm-realised operators" when none apply. Still makes NO call.
- Example: `nlir -e 'foo?' --dry-run --mode llm` → DAG `(foo ?)` + `` `?` -> model `echo` (command)  NLIR_PROMPT=Answer this: <text>foo</text>  $ … ``.

## Diff summary

- Files touched: `src/llm.rs` (`realise_llm_preview` + 2 tests), `src/main.rs` (`preview_llm_prompts`/`collect_llm_previews`/`operand_preview`; run_dry_run wiring), `test/integration.sh` (llm-preview assertion).
- Behavioural delta: `--dry-run` in llm mode now previews assembled prompts; det mode + no-op cases unchanged.

## Operator-takeaway

`--dry-run` is now complete (DAG + assembled prompts, no calls). This closes the
last nlir-code bead in my orbit — I took it CLI-side (additive `realise_llm_preview`
+ a main.rs AST walk) since aur-1's eval lane is held on your parallelism decision.
Nested-subcall operands show as source `«…»` rather than their evaluated value;
aur-1 can later upgrade that to real child values when they build the eval
dry-walk. Every nlir lane is now drained.
