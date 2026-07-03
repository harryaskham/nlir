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
//! Operator sigils (`# ! & | …`, bd-16d8fc), builtin sigils (`; $ ^ = [ ] , ( )`
//! and the backtick, bd-cee855), and the `^`/`$` sub-forms with role-modifier /
//! negative-index disambiguation (bd-4c951c) are all handled. Only a character
//! that is neither a literal, a configured operator, nor a builtin sigil is a
//! lex error.

use std::fmt;

/// The role-filtered message view selected by a `^` sigil (SPEC §Message
/// indexing): `^` assistant (default), `^_` user, `^*` all, `^/` system.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MessageRole {
    /// `^` — assistant messages (the default view).
    Assistant,
    /// `^_` — user messages.
    User,
    /// `^*` — all messages.
    All,
    /// `^/` — system messages.
    System,
}

impl MessageRole {
    /// The sigil suffix (`""`, `"_"`, `"*"`, `"/"`).
    #[must_use]
    pub const fn suffix(self) -> &'static str {
        match self {
            MessageRole::Assistant => "",
            MessageRole::User => "_",
            MessageRole::All => "*",
            MessageRole::System => "/",
        }
    }
}

/// A lexical token. The literal, operator, builtin-sigil, and `^`/`$` sub-form
/// layers are all produced (bd-a14b8a/5e6a92/80e0d1/16d8fc/cee855/4c951c).
#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    /// A bare literal (`[a-zA-Z0-9]` runs plus POSIX escapes that let it contain
    /// spaces/sigils). An all-ASCII-digit bare token is also a numeric literal
    /// in numeric positions.
    Bare(String),
    /// A quoted literal: `content` is the resolved text (raw for `'…'`,
    /// POSIX-escape-processed for `"…"`); `interpolate` is true for `"…"` so the
    /// evaluator interpolates bare `$name` at eval time (SPEC §Interpolation),
    /// and false for raw `'…'`.
    Quoted { content: String, interpolate: bool },
    /// A configured operator sigil (bd-16d8fc), matched longest-first so `**`
    /// beats `*`.
    Operator(String),
    /// A numeric literal. Emitted for a negative index right after `^` (bd-4c951c);
    /// positive/plain numbers otherwise arrive as digit [`Token::Bare`]s.
    Number(f64),
    /// `;` — statement separator (evaluate + push).
    Semicolon,
    /// `[` — list-literal open.
    LBracket,
    /// `]` — list-literal close.
    RBracket,
    /// `,` — list-literal separator.
    Comma,
    /// `(` — grouping open.
    LParen,
    /// `)` — grouping close.
    RParen,
    /// `` ` `` — serial-evaluation marker.
    Backtick,
    /// `=` — assignment (the parser treats a preceding bare as the LHS key).
    Equals,
    /// `$name` — read `context[name]` (name may be a `_`-prefixed system key).
    ContextRead(String),
    /// `$` — peek the stack top.
    StackPeek,
    /// `$N` / `$-N` — peek the stack by (possibly negative) index.
    StackIndex(i64),
    /// `^` / `^_` / `^*` / `^/` — a role-filtered message index; the index
    /// expression follows as subsequent tokens.
    Message(MessageRole),
}

impl Token {
    /// A display rendering of this token (used by `nlir parse`'s token dump).
    #[must_use]
    pub fn render(&self) -> String {
        match self {
            Token::Bare(s) | Token::Operator(s) => s.clone(),
            Token::Quoted { content, .. } => content.clone(),
            Token::Number(n) => format_number(*n),
            Token::Semicolon => ";".to_owned(),
            Token::LBracket => "[".to_owned(),
            Token::RBracket => "]".to_owned(),
            Token::Comma => ",".to_owned(),
            Token::LParen => "(".to_owned(),
            Token::RParen => ")".to_owned(),
            Token::Backtick => "`".to_owned(),
            Token::Equals => "=".to_owned(),
            Token::ContextRead(name) => format!("${name}"),
            Token::StackPeek => "$".to_owned(),
            Token::StackIndex(n) => format!("${n}"),
            Token::Message(role) => format!("^{}", role.suffix()),
        }
    }

    /// The numeric value when this token is a numeric literal: an all-ASCII-digit
    /// bare literal, or an explicit [`Token::Number`]. Other tokens return `None`.
    #[must_use]
    pub fn numeric_value(&self) -> Option<f64> {
        match self {
            Token::Bare(s) if !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()) => {
                s.parse().ok()
            }
            Token::Number(n) => Some(*n),
            _ => None,
        }
    }
}

/// Format a number for [`Token::render`]: integer-valued numbers render without a
/// decimal point (`-1`, `42`), others via the default float formatting.
fn format_number(n: f64) -> String {
    if n.fract() == 0.0 && n.is_finite() {
        format!("{}", n as i64)
    } else {
        format!("{n}")
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

/// Tokenise a shorthand expression into its full token stream (literals,
/// operators, builtin sigils, and `^`/`$` sub-forms).
///
/// Whitespace between tokens is discarded. `op_sigils` are the configured
/// operator sigils (matched longest-first). A leading `-` immediately after a
/// `^` message sigil is a negative index, not the subtract operator (bd-4c951c;
/// the `$` sigil folds its own `$-N` index). A character that is neither a
/// literal, a configured operator, nor a builtin sigil is a [`LexError`].
pub fn tokenize(input: &str, op_sigils: &[String]) -> Result<Vec<Token>, LexError> {
    let chars: Vec<char> = input.chars().collect();
    let mut tokens = Vec::new();
    let mut i = 0;
    // Set right after a `^` message sigil so a following `-<digits>` lexes as a
    // negative index (Number) rather than the subtract operator. Preserved across
    // intervening whitespace.
    let mut after_caret = false;
    // Set right after any value-producing token so a following `_` lexes as the
    // configured `_` operator (operand position) rather than the start of a
    // `_`-prefixed system key (nud position). Preserved across whitespace like
    // `after_caret` (bd-ebf385).
    let mut prev_is_value = false;
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
            continue;
        }
        let was_after_caret = after_caret;
        after_caret = false;
        match c {
            // Negative index right after `^` (bd-4c951c).
            '-' if was_after_caret && chars.get(i + 1).is_some_and(char::is_ascii_digit) => {
                let (n, next) = read_signed_number(&chars, i)?;
                tokens.push(Token::Number(n));
                i = next;
            }
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
            // A `_`-prefixed system key (`_sep`, `_cache`, …) in operand
            // position. A `_` that follows a value is instead the configured
            // `_` operator sigil, handled below via `match_operator` (bd-ebf385).
            '_' if !prev_is_value
                && chars.get(i + 1).is_some_and(|n| n.is_ascii_alphanumeric()) =>
            {
                let (tok, next) = lex_bare(&chars, i)?;
                tokens.push(tok);
                i = next;
            }
            // A bare literal starts with an alphanumeric or an escape.
            '\\' | 'a'..='z' | 'A'..='Z' | '0'..='9' => {
                let (tok, next) = lex_bare(&chars, i)?;
                tokens.push(tok);
                i = next;
            }
            ';' => {
                tokens.push(Token::Semicolon);
                i += 1;
            }
            '[' => {
                tokens.push(Token::LBracket);
                i += 1;
            }
            ']' => {
                tokens.push(Token::RBracket);
                i += 1;
            }
            ',' => {
                tokens.push(Token::Comma);
                i += 1;
            }
            '(' => {
                tokens.push(Token::LParen);
                i += 1;
            }
            ')' => {
                tokens.push(Token::RParen);
                i += 1;
            }
            '`' => {
                tokens.push(Token::Backtick);
                i += 1;
            }
            '=' => {
                tokens.push(Token::Equals);
                i += 1;
            }
            '$' => {
                let (tok, next) = lex_dollar(&chars, i)?;
                tokens.push(tok);
                i = next;
            }
            '^' => {
                let (tok, next) = lex_caret(&chars, i);
                tokens.push(tok);
                i = next;
                after_caret = true;
            }
            other => {
                if let Some((op, next)) = match_operator(&chars, i, op_sigils) {
                    tokens.push(Token::Operator(op));
                    i = next;
                } else {
                    return Err(LexError {
                        position: i,
                        message: format!(
                            "unexpected character {other:?} (not a configured operator or builtin sigil)"
                        ),
                    });
                }
            }
        }
        prev_is_value = matches!(
            tokens.last(),
            Some(
                Token::Bare(_)
                    | Token::Quoted { .. }
                    | Token::Number(_)
                    | Token::RParen
                    | Token::RBracket
                    | Token::ContextRead(_)
                    | Token::StackPeek
                    | Token::StackIndex(_)
            )
        );
    }
    Ok(tokens)
}

/// Lex a `$` sub-form (SPEC §Context, §Builtins): `$name` context read (name may
/// be a `_`-prefixed system key), `$N` / `$-N` stack index, else bare `$` peek.
fn lex_dollar(chars: &[char], start: usize) -> Result<(Token, usize), LexError> {
    match chars.get(start + 1).copied() {
        // $name / $_system_key
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {
            let mut j = start + 1;
            while j < chars.len() && (chars[j].is_ascii_alphanumeric() || chars[j] == '_') {
                j += 1;
            }
            let name: String = chars[start + 1..j].iter().collect();
            Ok((Token::ContextRead(name), j))
        }
        // $N or $-N (bd-4c951c: leading `-` is a negative index, not subtract)
        Some(c)
            if c.is_ascii_digit()
                || (c == '-' && chars.get(start + 2).is_some_and(char::is_ascii_digit)) =>
        {
            let (n, next) = read_signed_int(chars, start + 1)?;
            Ok((Token::StackIndex(n), next))
        }
        // bare `$` — stack top peek
        _ => Ok((Token::StackPeek, start + 1)),
    }
}

/// Lex a `^` message sigil with its optional role modifier (bd-4c951c): `^`
/// assistant, `^_` user, `^*` all, `^/` system. The index expression follows.
fn lex_caret(chars: &[char], start: usize) -> (Token, usize) {
    let (role, end) = match chars.get(start + 1).copied() {
        Some('_') => (MessageRole::User, start + 2),
        Some('*') => (MessageRole::All, start + 2),
        Some('/') => (MessageRole::System, start + 2),
        _ => (MessageRole::Assistant, start + 1),
    };
    (Token::Message(role), end)
}

/// Read a `-?[0-9]+` integer starting at `start` (used for `$` stack indices).
fn read_signed_int(chars: &[char], start: usize) -> Result<(i64, usize), LexError> {
    let mut j = start;
    if chars.get(j) == Some(&'-') {
        j += 1;
    }
    while j < chars.len() && chars[j].is_ascii_digit() {
        j += 1;
    }
    let s: String = chars[start..j].iter().collect();
    let n = s.parse::<i64>().map_err(|_| LexError {
        position: start,
        message: format!("invalid stack index {s:?}"),
    })?;
    Ok((n, j))
}

/// Read a `-[0-9]+` negative number starting at `start` (used for the negative
/// index right after `^`).
fn read_signed_number(chars: &[char], start: usize) -> Result<(f64, usize), LexError> {
    let mut j = start + 1;
    while j < chars.len() && chars[j].is_ascii_digit() {
        j += 1;
    }
    let s: String = chars[start..j].iter().collect();
    let n = s.parse::<f64>().map_err(|_| LexError {
        position: start,
        message: format!("invalid number {s:?}"),
    })?;
    Ok((n, j))
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
    // A single leading `_` marks a `_`-prefixed system key (`_sep`, `_cache`).
    // `_` is NOT a mid-token continuation char, so `xxx_2` splits at `_` and the
    // configured `_` operator can match (bd-ebf385).
    if chars.get(i) == Some(&'_') {
        out.push('_');
        i += 1;
    }
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
            return Ok((
                Token::Quoted {
                    content: out,
                    interpolate: false,
                },
                i + 1,
            ));
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
            '"' => {
                return Ok((
                    Token::Quoted {
                        content: out,
                        interpolate: true,
                    },
                    i + 1,
                ));
            }
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
            .map(|t| t.render())
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
        assert_eq!(tokenize("007", NO_OPS).unwrap()[0].render(), "007");
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
            vec![Token::Quoted {
                content: "a\\nb".to_owned(),
                interpolate: false
            }]
        );
        // Multiple tokens around a raw quote.
        assert_eq!(bares("foo 'bar baz' qux"), vec!["foo", "bar baz", "qux"]);
    }

    #[test]
    fn double_quotes_process_escapes_but_keep_interpolation_literal() {
        assert_eq!(
            tokenize("\"a\\tb\"", NO_OPS).unwrap(),
            vec![Token::Quoted {
                content: "a\tb".to_owned(),
                interpolate: true
            }]
        );
        assert_eq!(
            tokenize("\"a\\nb\"", NO_OPS).unwrap(),
            vec![Token::Quoted {
                content: "a\nb".to_owned(),
                interpolate: true
            }]
        );
        // $name interpolation is eval-time; the lexer keeps it literal.
        assert_eq!(
            tokenize("\"the subject is $k\"", NO_OPS).unwrap(),
            vec![Token::Quoted {
                content: "the subject is $k".to_owned(),
                interpolate: true
            }]
        );
        // Escaped quote inside a double quote.
        assert_eq!(
            tokenize("\"a\\\"b\"", NO_OPS).unwrap(),
            vec![Token::Quoted {
                content: "a\"b".to_owned(),
                interpolate: true
            }]
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

    #[test]
    fn builtin_structural_sigils() {
        assert_eq!(
            tokenize("a;b", NO_OPS).unwrap(),
            vec![
                Token::Bare("a".to_owned()),
                Token::Semicolon,
                Token::Bare("b".to_owned()),
            ]
        );
        assert_eq!(
            tokenize("[a,b]", NO_OPS).unwrap(),
            vec![
                Token::LBracket,
                Token::Bare("a".to_owned()),
                Token::Comma,
                Token::Bare("b".to_owned()),
                Token::RBracket,
            ]
        );
        assert_eq!(
            tokenize("(a)`b", &ops(&["+"])).unwrap(),
            vec![
                Token::LParen,
                Token::Bare("a".to_owned()),
                Token::RParen,
                Token::Backtick,
                Token::Bare("b".to_owned()),
            ]
        );
        // key=RHS: the `=` is its own token; the parser treats the bare as the LHS.
        assert_eq!(
            tokenize("k=foo", NO_OPS).unwrap(),
            vec![
                Token::Bare("k".to_owned()),
                Token::Equals,
                Token::Bare("foo".to_owned()),
            ]
        );
    }

    #[test]
    fn dollar_sub_forms() {
        // $name context read (incl. _-prefixed system keys).
        assert_eq!(
            tokenize("$k", NO_OPS).unwrap(),
            vec![Token::ContextRead("k".to_owned())]
        );
        assert_eq!(
            tokenize("$_messages", NO_OPS).unwrap(),
            vec![Token::ContextRead("_messages".to_owned())]
        );
        // $N and $-N stack index (negative index, not subtract; bd-4c951c).
        assert_eq!(tokenize("$0", NO_OPS).unwrap(), vec![Token::StackIndex(0)]);
        assert_eq!(
            tokenize("$-1", NO_OPS).unwrap(),
            vec![Token::StackIndex(-1)]
        );
        // bare $ peeks the stack top.
        assert_eq!(
            tokenize("$;$", NO_OPS).unwrap(),
            vec![Token::StackPeek, Token::Semicolon, Token::StackPeek]
        );
    }

    #[test]
    fn caret_role_modifiers_and_negative_index() {
        let ops = ops(&["+", "-"]);
        // Role modifiers `_ * /` right after `^` (bd-4c951c), not operators.
        assert_eq!(
            tokenize("^1", &ops).unwrap(),
            vec![
                Token::Message(MessageRole::Assistant),
                Token::Bare("1".to_owned())
            ]
        );
        assert_eq!(
            tokenize("^_1", &ops).unwrap(),
            vec![
                Token::Message(MessageRole::User),
                Token::Bare("1".to_owned())
            ]
        );
        assert_eq!(
            tokenize("^*1", &ops).unwrap(),
            vec![
                Token::Message(MessageRole::All),
                Token::Bare("1".to_owned())
            ]
        );
        assert_eq!(
            tokenize("^/1", &ops).unwrap(),
            vec![
                Token::Message(MessageRole::System),
                Token::Bare("1".to_owned())
            ]
        );
        // `^-1`: the `-` is a negative index, NOT the subtract operator (bd-4c951c).
        assert_eq!(
            tokenize("^-1", &ops).unwrap(),
            vec![Token::Message(MessageRole::Assistant), Token::Number(-1.0)]
        );
        assert_eq!(
            tokenize("^_-1", &ops).unwrap(),
            vec![Token::Message(MessageRole::User), Token::Number(-1.0)]
        );
        // Away from `^`, `-` is the subtract operator.
        assert_eq!(
            tokenize("3-1", &ops).unwrap(),
            vec![
                Token::Bare("3".to_owned()),
                Token::Operator("-".to_owned()),
                Token::Bare("1".to_owned()),
            ]
        );
        // Range form `M^N` (parser distinguishes prefix vs infix `^`).
        assert_eq!(
            tokenize("1^3", &ops).unwrap(),
            vec![
                Token::Bare("1".to_owned()),
                Token::Message(MessageRole::Assistant),
                Token::Bare("3".to_owned()),
            ]
        );
        assert_eq!(Token::Number(-1.0).numeric_value(), Some(-1.0));
    }

    #[test]
    fn underscore_key_vs_echo_operator() {
        let op_sigils = ops(&["_"]);
        // `_` after a value is the configured operator, so `xxx_2` splits
        // (bd-ebf385: det-echo `xxx_2` -> `xxx _ 2`).
        assert_eq!(
            tokenize("xxx_2", &op_sigils).unwrap(),
            vec![
                Token::Bare("xxx".to_owned()),
                Token::Operator("_".to_owned()),
                Token::Bare("2".to_owned()),
            ]
        );
        assert_eq!(
            tokenize("a_b", &op_sigils).unwrap(),
            vec![
                Token::Bare("a".to_owned()),
                Token::Operator("_".to_owned()),
                Token::Bare("b".to_owned()),
            ]
        );
        // A `_`-prefixed system key in operand position stays one bare
        // (det-sep `_sep=\ `).
        assert_eq!(
            tokenize("_sep=x", &op_sigils).unwrap(),
            vec![
                Token::Bare("_sep".to_owned()),
                Token::Equals,
                Token::Bare("x".to_owned()),
            ]
        );
        // A `_`-key lexes even when `_` is not a configured operator.
        assert_eq!(
            tokenize("_cache", NO_OPS).unwrap(),
            vec![Token::Bare("_cache".to_owned())]
        );
    }
}
