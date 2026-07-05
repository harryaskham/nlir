# ^! tool/code message view (Harry's agentic-pipe ask)

## What
A new `^` role-view for tool-call results + code messages, so agentic/coding contexts are addressable: `^!-1` = last tool result, `~^!` = distil all tool output, `#^!` = topic of tool activity, `0^!-1` = the tool stream. Harry's direction: nlir as a smart pipe over coding tasks; aur-2's divvy assigned `^!` to my `^`-views lane (aur-2 owns $_stdin, aur-1 the file-load op).

## How (my message-views lane — separate from the operators/models config sections in flight)
- lexer.rs: MessageRole::Tool variant + suffix "!"; lex_caret adds `Some('!') => Tool`. `^!` lexes as the tool view even when `!` is a configured negate op (lex_caret consumes the modifier before operator matching).
- messages.rs: effective_roles maps Tool -> views.tool.
- config.rs: MessageViews gains a `tool` field; Default = [tool, tool_result, function] (covers OpenAI/Anthropic tool-result roles). Serde `#[serde(default)]` on the struct means existing configs without `tool:` auto-fill it -> zero breakage.
- config.example.yaml: views gains `tool: [tool, tool_result, function]`.
- Additive: `^`/`^_`/`^*`/`^/` + bare-views + indexed/range forms all unchanged.

## Proof (exit-code gated + live)
237 lib tests (+^! lexer/effective_roles coverage), clippy -D both feature sets, fmt -- all exit=0. Live on a coding context with a tool-role message: `^!-1` -> the FAILED test line verbatim; `~^!` -> a crisp one-line failure summary. det 18/18.

## Next
Enables the coding-pipe showcase moves (e.g. `~^!` = "what did the tools just tell us", `#^!` = the failing area). Coordinate with aur-2 ($_stdin) + aur-1 (file-load op) for the full smart-pipe story.
