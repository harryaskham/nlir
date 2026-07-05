#!/usr/bin/env bash
# nlir SMART PIPE · aur1 · 01 — nlir as a unix filter over CODE
#
# nlir reads piped stdin as $_stdin, so it drops straight into a shell pipeline.
# Point it at a source file (or a diff, a log, anything) and pull the signal out:
#
#     cat file.rs | nlir -e '#$_stdin'    → the core concept, one noun phrase
#     cat file.rs | nlir -e '~$_stdin'    → the gist, one line
#     cat file.rs | nlir -e ':$_stdin'    → a plain-English walkthrough
#     git diff    | nlir -e '~$_stdin'    → the commit message writes itself
#
# And it CHAINS — nlir is just another filter:
#     cat file | nlir -e '#$_stdin' | next-tool
#
# HOW TO REUSE IT (type this in your shell) on any code you want to understand:
#     |cat src/lib.rs | nlir -e '~$_stdin'
#     |git diff        | nlir -e ':$_stdin'
#     |curl -s $URL     | nlir -e '#$_stdin'
#
# Run:  ./examples/pipe-aur1-01-smart-pipe.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

CODE='fn retry<T, E>(mut f: impl FnMut() -> Result<T, E>, tries: u32) -> Result<T, E> {
    let mut last = f();
    for _ in 0..tries {
        if last.is_ok() { return last; }
        last = f();
    }
    last
}'

say "nlir AS A SMART PIPE — point it at code on stdin, pull the signal out (\$_stdin)"
echo "  the code (piped in):"; printf '%s\n' "$CODE" | sed 's/^/    /'
echo    "  #\$_stdin  the concept:"; printf '%s' "$CODE" | "$NLIR" -e '#$_stdin' --quiet | fold -s -w 82 | sed 's/^/     /'
echo -n "  ~\$_stdin  the gist     => "; printf '%s' "$CODE" | "$NLIR" -e '~$_stdin' --quiet | fold -s -w 74 | sed '2,$s/^/                            /'
say "  :\$_stdin  plain English:"; printf '%s' "$CODE" | "$NLIR" -e ':$_stdin' --quiet | fold -s -w 82 | sed 's/^/     /'

say "It's a unix filter: cat file | nlir -e '…' | next-tool. Reads code, diffs, logs — anything on stdin."
