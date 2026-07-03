//! nlir parser — precedence-climbing (Pratt) core (bd-70698b / bd-efe1ee).
//!
//! Turns a [`crate::lexer`] token stream into an [`Expr`] AST, driven by the
//! config operator table (SPEC §Mental model, §Grammar & parsing). Binding power
//! comes from each operator's `priority` (higher binds tighter; default 9), and
//! placement from its `fixity`:
//!
//! - **prefix** (`# !`) takes one right operand and, with a high priority, binds
//!   above binary operators — `!a&b` parses as `(!a)&b` (bd-efe1ee);
//! - **infix** (`- /`) is binary, left-associative;
//! - **postfix** (`?`, loose) binds everything to its left;
//! - **mixfix** (`& | + *`) is treated as left-associative binary here; the
//!   variadic-flattening bead (bd-c65341) collapses the binary chain into a
//!   single n-ary application.
//!
//! Also handled: grouping `(…)` (preserved as [`Expr::Group`]) and the `^`
//! message-index prefix (`^N`, tightest). Deferred to later parser/message beads:
//! list literals `[a,b,c]`, statement split `;` + DAG, the backtick serial
//! marker, assignment `=`, and the `M^N` message-range infix form.

use std::collections::BTreeMap;
use std::fmt;

use crate::config::{Fixity, OperatorConfig};
use crate::lexer::{MessageRole, Token};

/// Default operator priority when the config leaves it unset. Per SPEC's
/// precedence ladder the default is per-fixity so the coarse ordering holds
/// without every config setting explicit priorities: prefix binds above binary,
/// which binds above the loose postfix. The finer binary ladder
/// (`**` > `* /` > `+ -`) is achieved by setting explicit config priorities.
pub const DEFAULT_PRIORITY: i64 = 9;
/// The `^` message index binds tightest (SPEC precedence ladder: `^` = 20).
pub const CARET_PRIORITY: i64 = 20;

/// The default priority for an operator of the given fixity when the config
/// leaves `priority` unset (SPEC ladder: prefix 14, binary 9, postfix 1).
fn default_priority(fixity: Fixity) -> i64 {
    match fixity {
        Fixity::Prefix => 14,
        Fixity::Postfix => 1,
        Fixity::Infix | Fixity::Mixfix => DEFAULT_PRIORITY,
    }
}

/// The parsed expression AST.
#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    /// A bare literal.
    Bare(String),
    /// A numeric literal.
    Number(f64),
    /// A quoted literal's content.
    Quoted(String),
    /// `$name` — a context read.
    ContextRead(String),
    /// `$` — peek the stack top.
    StackPeek,
    /// `$N` / `$-N` — peek the stack by index.
    StackIndex(i64),
    /// `^`/`^_`/`^*`/`^/` message index over the given index expression.
    Message { role: MessageRole, index: Box<Expr> },
    /// A parenthesised sub-expression (parens are preserved in output).
    Group(Box<Expr>),
    /// An operator application; `operands.len()` is 1 for prefix/postfix, 2 for
    /// infix/mixfix (until variadic flattening makes mixfix n-ary).
    Apply {
        op: String,
        fixity: Fixity,
        operands: Vec<Expr>,
    },
}

impl Expr {
    /// A structural, fully-parenthesised rendering used for the AST dump / tests.
    #[must_use]
    pub fn render(&self) -> String {
        match self {
            Expr::Bare(s) | Expr::Quoted(s) => s.clone(),
            Expr::Number(n) => {
                if n.fract() == 0.0 && n.is_finite() {
                    format!("{}", *n as i64)
                } else {
                    format!("{n}")
                }
            }
            Expr::ContextRead(name) => format!("${name}"),
            Expr::StackPeek => "$".to_owned(),
            Expr::StackIndex(n) => format!("${n}"),
            Expr::Message { role, index } => format!("^{}{}", role.suffix(), index.render()),
            Expr::Group(inner) => inner.render(),
            Expr::Apply {
                op,
                fixity,
                operands,
            } => match (fixity, operands.as_slice()) {
                (Fixity::Prefix, [a]) => format!("({op} {})", a.render()),
                (Fixity::Postfix, [a]) => format!("({} {op})", a.render()),
                (_, [a, b]) => format!("({} {op} {})", a.render(), b.render()),
                _ => {
                    let parts: Vec<String> = operands.iter().map(Expr::render).collect();
                    format!("({op} {})", parts.join(" "))
                }
            },
        }
    }
}

/// A parser error, carrying the (token-index) position for diagnostics.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParseError {
    /// Zero-based token index where the problem was found.
    pub position: usize,
    /// Human-readable description.
    pub message: String,
}

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "parse error at token {}: {}",
            self.position, self.message
        )
    }
}

impl std::error::Error for ParseError {}

/// Fixity + resolved priority for one operator sigil.
#[derive(Debug, Clone, Copy)]
struct OpInfo {
    fixity: Fixity,
    priority: i64,
}

/// Build the sigil → [`OpInfo`] table from the config operator definitions.
fn op_table(operators: &BTreeMap<String, OperatorConfig>) -> BTreeMap<String, OpInfo> {
    operators
        .values()
        .map(|o| {
            (
                o.op.clone(),
                OpInfo {
                    fixity: o.fixity,
                    priority: o.priority.unwrap_or_else(|| default_priority(o.fixity)),
                },
            )
        })
        .collect()
}

/// Binding power from a priority (doubled so left-associativity has room).
fn bp(priority: i64) -> u32 {
    u32::try_from(priority.max(0))
        .unwrap_or(u32::MAX / 2)
        .saturating_mul(2)
}

/// Parse a single-statement expression from `tokens`, using `operators` for
/// fixity/priority. Errors on trailing tokens or unsupported constructs.
pub fn parse_expr(
    tokens: &[Token],
    operators: &BTreeMap<String, OperatorConfig>,
) -> Result<Expr, ParseError> {
    let table = op_table(operators);
    let mut parser = Parser {
        tokens,
        table: &table,
        pos: 0,
    };
    let expr = parser.expr(0)?;
    if parser.pos != tokens.len() {
        return Err(ParseError {
            position: parser.pos,
            message: format!("unexpected trailing token {:?}", tokens[parser.pos]),
        });
    }
    Ok(expr)
}

struct Parser<'a> {
    tokens: &'a [Token],
    table: &'a BTreeMap<String, OpInfo>,
    pos: usize,
}

impl Parser<'_> {
    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    /// If the next token is a configured operator, return its sigil + info.
    fn peek_led(&self) -> Option<(String, OpInfo)> {
        match self.peek() {
            Some(Token::Operator(op)) => self.table.get(op).map(|info| (op.clone(), *info)),
            _ => None,
        }
    }

    fn expr(&mut self, min_bp: u32) -> Result<Expr, ParseError> {
        let mut lhs = self.nud()?;
        while let Some((op, info)) = self.peek_led() {
            match info.fixity {
                Fixity::Postfix => {
                    let l_bp = bp(info.priority);
                    if l_bp < min_bp {
                        break;
                    }
                    self.pos += 1;
                    lhs = Expr::Apply {
                        op,
                        fixity: Fixity::Postfix,
                        operands: vec![lhs],
                    };
                }
                Fixity::Infix | Fixity::Mixfix => {
                    let l_bp = bp(info.priority);
                    if l_bp < min_bp {
                        break;
                    }
                    self.pos += 1;
                    let rhs = self.expr(l_bp + 1)?;
                    lhs = Expr::Apply {
                        op,
                        fixity: info.fixity,
                        operands: vec![lhs, rhs],
                    };
                }
                // A prefix operator cannot appear in led (infix) position.
                Fixity::Prefix => break,
            }
        }
        Ok(lhs)
    }

    fn nud(&mut self) -> Result<Expr, ParseError> {
        let start = self.pos;
        let tok = self
            .tokens
            .get(self.pos)
            .ok_or_else(|| ParseError {
                position: start,
                message: "unexpected end of input".to_owned(),
            })?
            .clone();
        self.pos += 1;
        match tok {
            Token::Bare(s) => Ok(Expr::Bare(s)),
            Token::Number(n) => Ok(Expr::Number(n)),
            Token::Quoted(s) => Ok(Expr::Quoted(s)),
            Token::ContextRead(s) => Ok(Expr::ContextRead(s)),
            Token::StackPeek => Ok(Expr::StackPeek),
            Token::StackIndex(n) => Ok(Expr::StackIndex(n)),
            Token::Message(role) => {
                let index = self.expr(bp(CARET_PRIORITY))?;
                Ok(Expr::Message {
                    role,
                    index: Box::new(index),
                })
            }
            Token::LParen => {
                let inner = self.expr(0)?;
                match self.tokens.get(self.pos) {
                    Some(Token::RParen) => {
                        self.pos += 1;
                        Ok(Expr::Group(Box::new(inner)))
                    }
                    _ => Err(ParseError {
                        position: self.pos,
                        message: "expected ')'".to_owned(),
                    }),
                }
            }
            Token::Operator(op) => match self.table.get(&op) {
                Some(info) if info.fixity == Fixity::Prefix => {
                    let operand = self.expr(bp(info.priority))?;
                    Ok(Expr::Apply {
                        op,
                        fixity: Fixity::Prefix,
                        operands: vec![operand],
                    })
                }
                _ => Err(ParseError {
                    position: start,
                    message: format!("operator {op:?} is not valid in prefix position"),
                }),
            },
            other => Err(ParseError {
                position: start,
                message: format!("unexpected token {other:?}"),
            }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lexer::tokenize;

    /// A representative operator table following the SPEC precedence ladder.
    fn ladder() -> BTreeMap<String, OperatorConfig> {
        fn op(op: &str, fixity: Fixity, priority: i64) -> OperatorConfig {
            OperatorConfig {
                op: op.to_owned(),
                fixity,
                priority: Some(priority),
                ..OperatorConfig::default()
            }
        }
        BTreeMap::from([
            ("subject".to_owned(), op("#", Fixity::Prefix, 14)),
            ("not".to_owned(), op("!", Fixity::Prefix, 14)),
            ("pow".to_owned(), op("**", Fixity::Infix, 13)),
            ("mul".to_owned(), op("*", Fixity::Mixfix, 12)),
            ("div".to_owned(), op("/", Fixity::Infix, 12)),
            ("add".to_owned(), op("+", Fixity::Mixfix, 11)),
            ("sub".to_owned(), op("-", Fixity::Infix, 11)),
            ("and".to_owned(), op("&", Fixity::Mixfix, 9)),
            ("or".to_owned(), op("|", Fixity::Mixfix, 9)),
            ("question".to_owned(), op("?", Fixity::Postfix, 1)),
        ])
    }

    fn render(input: &str) -> String {
        let ops = ladder();
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        let tokens = tokenize(input, &sigils).expect("tokenises");
        parse_expr(&tokens, &ops).expect("parses").render()
    }

    #[test]
    fn atoms_parse() {
        assert_eq!(render("foo"), "foo");
        assert_eq!(render("123"), "123");
        assert_eq!(render("$k"), "$k");
        assert_eq!(render("$-1"), "$-1");
    }

    #[test]
    fn binary_precedence_and_left_assoc() {
        // `*` binds tighter than `+`.
        assert_eq!(render("1+2*3"), "(1 + (2 * 3))");
        // `**` tighter than `*`.
        assert_eq!(render("2*3**4"), "(2 * (3 ** 4))");
        // Left-associative subtraction.
        assert_eq!(render("a-b-c"), "((a - b) - c)");
    }

    #[test]
    fn prefix_binds_above_binary() {
        // bd-efe1ee: `!a&b` == `(!a)&b`.
        assert_eq!(render("!a&b"), "((! a) & b)");
        // `#^-1` — subject of the last message (prefix over a `^` index).
        assert_eq!(render("#^-1"), "(# ^-1)");
    }

    #[test]
    fn postfix_binds_leftward() {
        // bd-efe1ee: `?` is loose, so `a&b?` == `(a&b)?`.
        assert_eq!(render("a&b?"), "((a & b) ?)");
    }

    #[test]
    fn grouping_overrides_precedence_and_is_preserved() {
        assert_eq!(render("(1+2)*3"), "((1 + 2) * 3)");
        assert_eq!(render("!(a&b)"), "(! (a & b))");
    }

    #[test]
    fn message_index_prefix() {
        assert_eq!(render("^-1"), "^-1");
        assert_eq!(render("^_-1"), "^_-1");
    }

    #[test]
    fn default_precedence_without_explicit_priority() {
        // Operators with NO explicit priority default per fixity: prefix (14)
        // above binary (9) above postfix (1), so `!a&b?` == `((!a)&b)?`.
        fn op(op: &str, fixity: Fixity) -> OperatorConfig {
            OperatorConfig {
                op: op.to_owned(),
                fixity,
                priority: None,
                ..OperatorConfig::default()
            }
        }
        let ops = BTreeMap::from([
            ("not".to_owned(), op("!", Fixity::Prefix)),
            ("and".to_owned(), op("&", Fixity::Mixfix)),
            ("q".to_owned(), op("?", Fixity::Postfix)),
        ]);
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        let toks = tokenize("!a&b?", &sigils).expect("tokenises");
        assert_eq!(
            parse_expr(&toks, &ops).expect("parses").render(),
            "(((! a) & b) ?)"
        );
    }

    #[test]
    fn errors_are_located() {
        let ops = ladder();
        // Trailing unsupported token (list literal not parsed by the core yet).
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        let tokens = tokenize("[a,b]", &sigils).expect("tokenises");
        assert!(parse_expr(&tokens, &ops).is_err());
        // A dangling infix operand.
        let tokens = tokenize("a+", &sigils).expect("tokenises");
        assert!(parse_expr(&tokens, &ops).is_err());
    }
}
