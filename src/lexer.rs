//! nlir tokeniser — the literal layer (bd-a14b8a / bd-5e6a92 / bd-80e0d1).
//!
//! Turns shorthand text into a token stream (SPEC §Whitespace, escapes & quoting;
//! §Grammar Tokens). This layer handles:
//!
//! - **non-semantic whitespace** between tokens (spaces/tabs/newlines), so an
//!   expression can be laid out as a multi-line program;
//! - **bare literals** `[a-zA-Z0-9]+`, extended by POSIX escape sequences so a
//!   literal can contain spaces/sigils (`a\ b` → one token `a b`); an all-digit
//!   bare token doubles as a **numeric literal** in numeric positions (see
//!   [`Token::numeric_value`]);
//! - **quoted literals**: `'…'` raw (no escapes/interpolation), `"…"` with POSIX
//!   escapes processed. Eval-time `$name` interpolation inside `"…"` is applied
//!   later by the evaluator, so the lexer keeps `$name` literal in the content.
//!
//! Operator sigils (`# ! & | …`), builtin sigils (`; $ ^ = [ ] , ( )` and the
//! backtick), and the `^`/`$` sub-forms are added by later lexer beads
//! (bd-16d8fc / bd-cee855 / bd-4c951c); until then an unescaped occurrence of
//! such a character is a lex error rather than being silently absorbed.

use std::fmt;

/// A lexical token (literal + operator layers). More kinds (builtin sigils,
/// `^`/`$` sub-forms) are added by later lexer beads.
#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    /// A bare literal (`[a-zA-Z0-9]` runs plus POSIX escapes that let it contain
    /// spaces/sigils). An all-ASCII-digit bare token is also a numeric literal
    /// in numeric positions.
    Bare(String),
    /// A quoted literal's resolved content: raw for `'…'`, POSIX-escape-processed
    /// for `"…"`.
    Quoted(String),
    /// A configured operator sigil (bd-16d8fc), matched longest-first so `**`
    /// beats `*`. Operators are non-alphanumeric and never collide with reserved
    /// builtin sigils (enforced by config validation).
    Operator(String),
}

impl Token {
    /// The string carried by this token (bare/quoted text, or the operator sigil).
    #[must_use]
    pub fn text(&self) -> &str {
        match self {
            Token::Bare(s) | Token::Quoted(s) | Token::Operator(s) => s,
        }
    }

    /// The numeric value when this is an all-ASCII-digit **bare** literal (SPEC:
    /// numbers are numeric literals in numeric positions). Quoted literals and
    /// non-digit bare literals return `None`.
    #[must_use]
    pub fn numeric_value(&self) -> Option<f64> {
        match self {
            Token::Bare(s) if !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()) => {
                s.parse().ok()
            }
            _ => None,
        }
    }
}

/// A tokeniser error, carrying the (char-index) position for diagnostics.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LexError {
    /// Zero-based char index into the input where the problem was found.
    pub position: usize,
    /// Human-readable description.
    pub message: String,
}

impl fmt::Display for LexError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "lex error at position {}: {}",
            self.position, self.message
        )
    }
}

impl std::error::Error for LexError {}

/// Tokenise a shorthand expression's literal + operator layers.
///
/// Whitespace between tokens is discarded. Bare/quoted literals and configured
/// operator sigils (`op_sigils`, matched longest-first) are emitted as [`Token`]s.
/// Any other unescaped character (e.g. a builtin sigil) is a [`LexError`] for
/// now; later lexer beads extend the dispatch to handle those.
pub fn tokenize(input: &str, op_sigils: &[String]) -> Result<Vec<Token>, LexError> {
    let chars: Vec<char> = input.chars().collect();
    let mut tokens = Vec::new();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
            continue;
        }
        match c {
            '\'' => {
                let (tok, next) = lex_raw_quote(&chars, i)?;
                tokens.push(tok);
                i = next;
            }
            '"' => {
                let (tok, next) = lex_escaped_quote(&chars, i)?;
                tokens.push(tok);
                i = next;
            }
            // A bare literal starts with an alphanumeric or an escape.
            '\\' | 'a'..='z' | 'A'..='Z' | '0'..='9' => {
                let (tok, next) = lex_bare(&chars, i)?;
                tokens.push(tok);
                i = next;
            }
            other => {
                if let Some((op, next)) = match_operator(&chars, i, op_sigils) {
                    tokens.push(Token::Operator(op));
                    i = next;
                } else {
                    return Err(LexError {
                        position: i,
                        message: format!(
                            "unexpected character {other:?} (not a configured operator; builtin sigils are not lexed yet)"
                        ),
                    });
                }
            }
        }
    }
    Ok(tokens)
}

/// Match the LONGEST configured operator sigil that is a prefix of `chars[i..]`
/// (bd-16d8fc: `**` beats `*`). Returns the sigil and the index past it.
fn match_operator(chars: &[char], i: usize, op_sigils: &[String]) -> Option<(String, usize)> {
    let mut best: Option<(&str, usize)> = None;
    for sig in op_sigils {
        let sig_chars: Vec<char> = sig.chars().collect();
        if sig_chars.is_empty() || !chars[i..].starts_with(&sig_chars[..]) {
            continue;
        }
        let len = sig_chars.len();
        if best.is_none_or(|(_, best_len)| len > best_len) {
            best = Some((sig.as_str(), len));
        }
    }
    best.map(|(sig, len)| (sig.to_owned(), i + len))
}

/// Lex a bare literal starting at `start`: a run of `[a-zA-Z0-9]` and POSIX
/// escape sequences, ending at the first unescaped delimiter.
fn lex_bare(chars: &[char], start: usize) -> Result<(Token, usize), LexError> {
    let mut out = String::new();
    let mut i = start;
    while i < chars.len() {
        let c = chars[i];
        if c == '\\' {
            let (ch, next) = read_escape(chars, i)?;
            out.push(ch);
            i = next;
        } else if c.is_ascii_alphanumeric() {
            out.push(c);
            i += 1;
        } else {
            break;
        }
    }
    Ok((Token::Bare(out), i))
}

/// Lex a raw single-quoted literal `'…'` starting at `start` (no escapes, no
/// interpolation).
fn lex_raw_quote(chars: &[char], start: usize) -> Result<(Token, usize), LexError> {
    let mut out = String::new();
    let mut i = start + 1;
    loop {
        let Some(&c) = chars.get(i) else {
            return Err(LexError {
                position: start,
                message: "unterminated ' quote".to_owned(),
            });
        };
        if c == '\'' {
            return Ok((Token::Quoted(out), i + 1));
        }
        out.push(c);
        i += 1;
    }
}

/// Lex a double-quoted literal `"…"` starting at `start`, processing POSIX
/// escapes. `$name` interpolation is deferred to eval time, so it stays literal.
fn lex_escaped_quote(chars: &[char], start: usize) -> Result<(Token, usize), LexError> {
    let mut out = String::new();
    let mut i = start + 1;
    loop {
        let Some(&c) = chars.get(i) else {
            return Err(LexError {
                position: start,
                message: "unterminated \" quote".to_owned(),
            });
        };
        match c {
            '"' => return Ok((Token::Quoted(out), i + 1)),
            '\\' => {
                let (ch, next) = read_escape(chars, i)?;
                out.push(ch);
                i = next;
            }
            _ => {
                out.push(c);
                i += 1;
            }
        }
    }
}

/// Read a POSIX escape sequence at `chars[i] == '\\'`, returning the produced
/// char and the index past the sequence. `\n \t \\ \" \'` and `\<space>` map to
/// their control/literal chars; any other `\x` escapes to the literal `x` (so
/// sigils like `\;` or `\#` become `;` / `#`).
fn read_escape(chars: &[char], i: usize) -> Result<(char, usize), LexError> {
    let Some(&next) = chars.get(i + 1) else {
        return Err(LexError {
            position: i,
            message: "trailing backslash with nothing to escape".to_owned(),
        });
    };
    let ch = match next {
        'n' => '\n',
        't' => '\t',
        '\\' => '\\',
        '"' => '"',
        '\'' => '\'',
        ' ' => ' ',
        other => other,
    };
    Ok((ch, i + 2))
}

#[cfg(test)]
mod tests {
    use super::*;

    const NO_OPS: &[String] = &[];

    fn ops(list: &[&str]) -> Vec<String> {
        list.iter().map(|s| (*s).to_owned()).collect()
    }

    fn bares(input: &str) -> Vec<String> {
        tokenize(input, NO_OPS)
            .expect("tokenises")
            .into_iter()
            .map(|t| t.text().to_owned())
            .collect()
    }

    #[test]
    fn whitespace_between_tokens_is_non_semantic() {
        assert_eq!(bares("  foo\t\r\nbar   baz "), vec!["foo", "bar", "baz"]);
        // Multi-line program layout.
        assert_eq!(bares("foo\n  bar\n  baz"), vec!["foo", "bar", "baz"]);
        assert!(tokenize("", NO_OPS).unwrap().is_empty());
        assert!(tokenize("   \n\t ", NO_OPS).unwrap().is_empty());
    }

    #[test]
    fn bare_and_numeric_literals() {
        assert_eq!(bares("abc123"), vec!["abc123"]);
        let toks = tokenize("123", NO_OPS).unwrap();
        assert_eq!(toks, vec![Token::Bare("123".to_owned())]);
        assert_eq!(toks[0].numeric_value(), Some(123.0));
        // A bare with letters is not numeric.
        assert_eq!(tokenize("abc", NO_OPS).unwrap()[0].numeric_value(), None);
        assert_eq!(
            tokenize("007", NO_OPS).unwrap()[0].numeric_value(),
            Some(7.0)
        );
        // Text is preserved even when numeric (no leading-zero loss until coerced).
        assert_eq!(tokenize("007", NO_OPS).unwrap()[0].text(), "007");
    }

    #[test]
    fn escapes_extend_bare_literals() {
        // Escaped space keeps a single token.
        assert_eq!(
            tokenize("a\\ b", NO_OPS).unwrap(),
            vec![Token::Bare("a b".to_owned())]
        );
        // Escaped sigils become literal chars in the token.
        assert_eq!(
            tokenize("a\\;b", NO_OPS).unwrap(),
            vec![Token::Bare("a;b".to_owned())]
        );
        assert_eq!(
            tokenize("a\\&b", NO_OPS).unwrap(),
            vec![Token::Bare("a&b".to_owned())]
        );
        // Control escapes.
        assert_eq!(
            tokenize("a\\tb", NO_OPS).unwrap(),
            vec![Token::Bare("a\tb".to_owned())]
        );
        assert_eq!(
            tokenize("a\\nb", NO_OPS).unwrap(),
            vec![Token::Bare("a\nb".to_owned())]
        );
    }

    #[test]
    fn raw_single_quotes_are_literal() {
        assert_eq!(bares("'one two'"), vec!["one two"]);
        // No escape processing in raw quotes: backslash stays literal.
        assert_eq!(
            tokenize("'a\\nb'", NO_OPS).unwrap(),
            vec![Token::Quoted("a\\nb".to_owned())]
        );
        // Multiple tokens around a raw quote.
        assert_eq!(bares("foo 'bar baz' qux"), vec!["foo", "bar baz", "qux"]);
    }

    #[test]
    fn double_quotes_process_escapes_but_keep_interpolation_literal() {
        assert_eq!(
            tokenize("\"a\\tb\"", NO_OPS).unwrap(),
            vec![Token::Quoted("a\tb".to_owned())]
        );
        assert_eq!(
            tokenize("\"a\\nb\"", NO_OPS).unwrap(),
            vec![Token::Quoted("a\nb".to_owned())]
        );
        // $name interpolation is eval-time; the lexer keeps it literal.
        assert_eq!(
            tokenize("\"the subject is $k\"", NO_OPS).unwrap(),
            vec![Token::Quoted("the subject is $k".to_owned())]
        );
        // Escaped quote inside a double quote.
        assert_eq!(
            tokenize("\"a\\\"b\"", NO_OPS).unwrap(),
            vec![Token::Quoted("a\"b".to_owned())]
        );
    }

    #[test]
    fn unterminated_quotes_error() {
        assert_eq!(tokenize("'abc", NO_OPS).unwrap_err().position, 0);
        assert_eq!(tokenize("\"abc", NO_OPS).unwrap_err().position, 0);
        assert!(
            tokenize("'abc", NO_OPS)
                .unwrap_err()
                .message
                .contains("unterminated")
        );
    }

    #[test]
    fn operators_longest_match_and_split_bares() {
        let ops = ops(&["**", "*", "&", "!", "-", "+"]);
        // `**` beats `*` (longest-match, bd-16d8fc).
        assert_eq!(
            tokenize("2**3", &ops).unwrap(),
            vec![
                Token::Bare("2".to_owned()),
                Token::Operator("**".to_owned()),
                Token::Bare("3".to_owned()),
            ]
        );
        assert_eq!(
            tokenize("2*3", &ops).unwrap(),
            vec![
                Token::Bare("2".to_owned()),
                Token::Operator("*".to_owned()),
                Token::Bare("3".to_owned()),
            ]
        );
        // Operators split adjacent bares; prefix operator leads.
        assert_eq!(
            tokenize("a&b", &ops).unwrap(),
            vec![
                Token::Bare("a".to_owned()),
                Token::Operator("&".to_owned()),
                Token::Bare("b".to_owned()),
            ]
        );
        assert_eq!(
            tokenize("!foo", &ops).unwrap(),
            vec![
                Token::Operator("!".to_owned()),
                Token::Bare("foo".to_owned()),
            ]
        );
        // An escaped operator stays part of the bare literal.
        assert_eq!(
            tokenize("a\\&b", &ops).unwrap(),
            vec![Token::Bare("a&b".to_owned())]
        );
    }

    #[test]
    fn unlexed_sigils_error_for_now() {
        // With no configured operators, `&` is unknown.
        let err = tokenize("a&b", NO_OPS).unwrap_err();
        assert_eq!(err.position, 1);
        assert!(err.message.contains("not a configured operator"));
        // A char that is neither operator nor sigil errors even with ops configured.
        assert!(tokenize("a@b", &ops(&["&"])).is_err());
        // Trailing backslash is a clear error, not a panic.
        assert!(tokenize("abc\\", NO_OPS).is_err());
    }
}
