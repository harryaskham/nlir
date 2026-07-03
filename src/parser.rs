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
    /// A list literal `[a,b,c]` (SPEC: spreads into a variadic op, or renders to
    /// text by joining with `_sep`).
    List(Vec<Expr>),
    /// A backtick-marked forced-serial subtree (SPEC: `` ` `` is a low-precedence
    /// prefix over its whole RHS; the marked subtree evaluates serially inside
    /// while still running in parallel with respect to its siblings).
    Serial(Box<Expr>),
    /// `key = RHS` — a context assignment (SPEC §Context: read & assign). `key`
    /// is a literal key string (identifier; `_`-prefixed = system key); the RHS
    /// is an expression. Yields the value and writes context immediately
    /// (eval-side is bd-c85dee).
    Assign { key: String, value: Box<Expr> },
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
            Expr::List(items) => {
                let parts: Vec<String> = items.iter().map(Expr::render).collect();
                format!("[{}]", parts.join(", "))
            }
            Expr::Serial(inner) => format!("(` {})", inner.render()),
            Expr::Assign { key, value } => format!("({key} = {})", value.render()),
            Expr::Apply {
                op,
                fixity,
                operands,
            } => match (fixity, operands.as_slice()) {
                (Fixity::Prefix, [a]) => format!("({op} {})", a.render()),
                (Fixity::Postfix, [a]) => format!("({} {op})", a.render()),
                (Fixity::Mixfix, []) => format!("({op})"),
                (Fixity::Mixfix, [a]) => format!("({} {op})", a.render()),
                (Fixity::Mixfix, ops) => {
                    let parts: Vec<String> = ops.iter().map(Expr::render).collect();
                    format!("({})", parts.join(&format!(" {op} ")))
                }
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

/// A parsed program: a sequence of statements separated by `;` (SPEC §Mental
/// model). Each statement is an [`Expr`] tree; its operand subtrees are the
/// independent units the scheduler evaluates concurrently (execution-graph epic
/// bd-a32894), so the statement list + per-statement AST is the DAG skeleton.
#[derive(Debug, Clone, PartialEq)]
pub struct Program {
    /// The program's statements, in source order.
    pub statements: Vec<Expr>,
}

impl Program {
    /// Render the program as `stmt1; stmt2; …` (used by the `nlir parse` dump).
    #[must_use]
    pub fn render(&self) -> String {
        self.statements
            .iter()
            .map(Expr::render)
            .collect::<Vec<_>>()
            .join("; ")
    }
}

/// Parse a full program: split the token stream on top-level `;` into statements
/// and parse each as an expression (bd-acff69). An empty token stream is an empty
/// program; a trailing `;` is allowed; an empty middle statement (`a;;b`) errors.
pub fn parse_program(
    tokens: &[Token],
    operators: &BTreeMap<String, OperatorConfig>,
) -> Result<Program, ParseError> {
    let table = op_table(operators);
    let mut parser = Parser {
        tokens,
        table: &table,
        pos: 0,
    };
    let mut statements = Vec::new();
    while parser.pos < tokens.len() {
        let expr = parser.expr(0)?;
        statements.push(expr);
        match tokens.get(parser.pos) {
            Some(Token::Semicolon) => parser.pos += 1,
            None => break,
            Some(other) => {
                return Err(ParseError {
                    position: parser.pos,
                    message: format!("unexpected token {other:?} after statement"),
                });
            }
        }
    }
    Ok(Program { statements })
}

/// Fold a same-op mixfix chain into one n-ary [`Expr::Apply`] (bd-c65341). If
/// `lhs` is already a mixfix application of the same `op` (and not wrapped in a
/// [`Expr::Group`], which is a distinct node), append `rhs` to it; otherwise
/// build a fresh 2-operand application.
fn flatten_mixfix(op: String, lhs: Expr, rhs: Expr) -> Expr {
    match lhs {
        Expr::Apply {
            op: lop,
            fixity: Fixity::Mixfix,
            mut operands,
        } if lop == op => {
            operands.push(rhs);
            Expr::Apply {
                op,
                fixity: Fixity::Mixfix,
                operands,
            }
        }
        other => Expr::Apply {
            op,
            fixity: Fixity::Mixfix,
            operands: vec![other, rhs],
        },
    }
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

    /// Whether the current token can begin an expression (is nud-able). Used by
    /// mixfix unification to distinguish `[a,b]&x` (infix) from `[a,b]&`
    /// (postfix-on-list).
    fn starts_expr(&self) -> bool {
        match self.tokens.get(self.pos) {
            Some(
                Token::Bare(_)
                | Token::Number(_)
                | Token::Quoted(_)
                | Token::ContextRead(_)
                | Token::StackPeek
                | Token::StackIndex(_)
                | Token::Message(_)
                | Token::LParen
                | Token::LBracket
                | Token::Backtick,
            ) => true,
            Some(Token::Operator(op)) => matches!(
                self.table.get(op).map(|i| i.fixity),
                Some(Fixity::Prefix | Fixity::Mixfix)
            ),
            _ => false,
        }
    }

    /// Parse the comma-separated items of a list literal, assuming the opening
    /// `[` has already been consumed; stops after the closing `]`.
    fn parse_list_items(&mut self) -> Result<Vec<Expr>, ParseError> {
        let mut items = Vec::new();
        if matches!(self.tokens.get(self.pos), Some(Token::RBracket)) {
            self.pos += 1;
            return Ok(items);
        }
        loop {
            items.push(self.expr(0)?);
            match self.tokens.get(self.pos) {
                Some(Token::Comma) => self.pos += 1,
                Some(Token::RBracket) => {
                    self.pos += 1;
                    break;
                }
                _ => {
                    return Err(ParseError {
                        position: self.pos,
                        message: "expected ',' or ']' in list literal".to_owned(),
                    });
                }
            }
        }
        Ok(items)
    }

    fn expr(&mut self, min_bp: u32) -> Result<Expr, ParseError> {
        let mut lhs = self.nud()?;
        loop {
            // Assignment `key = RHS`: the builtin `=` is the loosest-binding,
            // right-associative form; its target must be a literal key (bd-4c3498).
            if matches!(self.peek(), Some(Token::Equals)) {
                const ASSIGN_BP: u32 = 1;
                if ASSIGN_BP < min_bp {
                    break;
                }
                let key = match &lhs {
                    Expr::Bare(k) => k.clone(),
                    _ => {
                        return Err(ParseError {
                            position: self.pos,
                            message: "assignment target must be a literal key".to_owned(),
                        });
                    }
                };
                self.pos += 1; // consume '='
                let value = self.expr(ASSIGN_BP)?;
                lhs = Expr::Assign {
                    key,
                    value: Box::new(value),
                };
                continue;
            }
            let Some((op, info)) = self.peek_led() else {
                break;
            };
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
                Fixity::Infix => {
                    let l_bp = bp(info.priority);
                    if l_bp < min_bp {
                        break;
                    }
                    self.pos += 1;
                    let rhs = self.expr(l_bp + 1)?;
                    lhs = Expr::Apply {
                        op,
                        fixity: Fixity::Infix,
                        operands: vec![lhs, rhs],
                    };
                }
                Fixity::Mixfix => {
                    let l_bp = bp(info.priority);
                    if l_bp < min_bp {
                        break;
                    }
                    self.pos += 1;
                    if self.starts_expr() {
                        // Infix use: fold same-op mixfix chains into one n-ary
                        // node (bd-c65341). A Group on either side forces nesting.
                        let rhs = self.expr(l_bp + 1)?;
                        lhs = flatten_mixfix(op, lhs, rhs);
                    } else {
                        // Postfix-on-list unification (bd-dab497): `[a,b,c]&`
                        // spreads the list into the operator's operands. A
                        // dangling mixfix operator with a non-list left operand
                        // and no right operand is an error.
                        match lhs {
                            Expr::List(items) => {
                                lhs = Expr::Apply {
                                    op,
                                    fixity: Fixity::Mixfix,
                                    operands: items,
                                };
                            }
                            _ => {
                                return Err(ParseError {
                                    position: self.pos,
                                    message: format!(
                                        "mixfix operator {op:?} needs a right operand or a list to spread"
                                    ),
                                });
                            }
                        }
                    }
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
            Token::LBracket => {
                let items = self.parse_list_items()?;
                Ok(Expr::List(items))
            }
            Token::Backtick => {
                // Low-precedence prefix: capture the whole RHS as a serial subtree.
                let inner = self.expr(0)?;
                Ok(Expr::Serial(Box::new(inner)))
            }
            Token::Operator(op) => match self.table.get(&op).copied() {
                Some(inf) if inf.fixity == Fixity::Prefix => {
                    let operand = self.expr(bp(inf.priority))?;
                    Ok(Expr::Apply {
                        op,
                        fixity: Fixity::Prefix,
                        operands: vec![operand],
                    })
                }
                Some(inf) if inf.fixity == Fixity::Mixfix => {
                    // Mixfix unification (bd-dab497) in prefix position:
                    // `&[a,b,c]` spreads the list; a bare `&` is a nullary-pop.
                    if matches!(self.tokens.get(self.pos), Some(Token::LBracket)) {
                        self.pos += 1;
                        let items = self.parse_list_items()?;
                        Ok(Expr::Apply {
                            op,
                            fixity: Fixity::Mixfix,
                            operands: items,
                        })
                    } else {
                        Ok(Expr::Apply {
                            op,
                            fixity: Fixity::Mixfix,
                            operands: Vec::new(),
                        })
                    }
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
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        // Statement separator ';' is not parsed by the core yet (trailing token).
        let tokens = tokenize("a;b", &sigils).expect("tokenises");
        assert!(parse_expr(&tokens, &ops).is_err());
        // A dangling infix operand.
        let tokens = tokenize("a+", &sigils).expect("tokenises");
        assert!(parse_expr(&tokens, &ops).is_err());
    }

    #[test]
    fn variadic_mixfix_flattening() {
        // A same-op mixfix chain flattens into one n-ary node (bd-c65341).
        assert_eq!(render("a&b&c"), "(a & b & c)");
        assert_eq!(render("a&b&c&d"), "(a & b & c & d)");
        assert_eq!(render("1+2+3"), "(1 + 2 + 3)");
        // Parens force nesting: a Group is a distinct node, so no flatten.
        assert_eq!(render("(a&b)&c"), "((a & b) & c)");
        assert_eq!(render("a&(b&c)"), "(a & (b & c))");
        // Different mixfix ops do not flatten together.
        assert_eq!(render("a&b|c"), "((a & b) | c)");
        // Infix operators stay nested binary (only mixfix flattens).
        assert_eq!(render("a-b-c"), "((a - b) - c)");
    }

    #[test]
    fn list_literals() {
        assert_eq!(render("[a,b,c]"), "[a, b, c]");
        assert_eq!(render("[]"), "[]");
        assert_eq!(render("[a]"), "[a]");
        // Expression and nested-list elements.
        assert_eq!(render("[a&b,c]"), "[(a & b), c]");
        assert_eq!(render("[[a,b],c]"), "[[a, b], c]");
        // A list as an operator operand.
        assert_eq!(render("x&[a,b]"), "(x & [a, b])");
        // A malformed / unclosed list errors.
        let ops = ladder();
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        assert!(parse_expr(&tokenize("[a,b", &sigils).unwrap(), &ops).is_err());
    }

    #[test]
    fn statement_split() {
        let ops = ladder();
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        let prog = |input: &str| {
            let toks = tokenize(input, &sigils).expect("tokenises");
            parse_program(&toks, &ops).expect("parses").render()
        };
        assert_eq!(prog("a;b;c"), "a; b; c");
        assert_eq!(prog("a&b;c-d"), "(a & b); (c - d)");
        assert_eq!(prog("a"), "a");
        assert_eq!(prog("a;b;"), "a; b"); // trailing ; is allowed
        assert_eq!(prog(""), ""); // empty program
        // Statement count.
        let toks = tokenize("a;b;c", &sigils).unwrap();
        assert_eq!(parse_program(&toks, &ops).unwrap().statements.len(), 3);
        // An empty middle statement errors.
        let toks = tokenize("a;;b", &sigils).unwrap();
        assert!(parse_program(&toks, &ops).is_err());
    }

    #[test]
    fn backtick_serial_marker() {
        // `` ` `` marks its RHS as a forced-serial subtree (bd-be5a84).
        assert_eq!(render("`a"), "(` a)");
        assert_eq!(render("`(a&b)"), "(` (a & b))");
        // Low precedence: it captures the whole RHS.
        assert_eq!(render("`a&b"), "(` (a & b))");
        // As an operand, `a + `(a+b)` keeps the two `+` operands parallel while
        // the backtick subtree is serial.
        assert_eq!(render("a+`(a+b)"), "(a + (` (a + b)))");
    }

    #[test]
    fn mixfix_unification() {
        // prefix-on-list and postfix-on-list spread to the same n-ary as a chain.
        assert_eq!(render("&[a,b,c]"), "(a & b & c)");
        assert_eq!(render("[a,b,c]&"), "(a & b & c)");
        assert_eq!(render("a&b&c"), "(a & b & c)");
        // nullary-pop: a bare mixfix operator has no operands (pops at eval).
        assert_eq!(render("&"), "(&)");
        // An infix mixfix with a list operand stays infix (list is not spread).
        assert_eq!(render("x&[a,b]"), "(x & [a, b])");
        // Postfix-on-list only fires when there is no following operand.
        assert_eq!(render("[a,b]&x"), "([a, b] & x)");
        // A dangling mixfix on a non-list left operand is an error.
        let ops = ladder();
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        assert!(parse_expr(&tokenize("a&", &sigils).unwrap(), &ops).is_err());
    }

    #[test]
    fn assignment() {
        // `key = RHS`: literal key, expression RHS (bd-4c3498).
        assert_eq!(render("k=foo"), "(k = foo)");
        assert_eq!(render("k=a+b"), "(k = (a + b))");
        // `_`-prefixed system keys lex and assign.
        assert_eq!(render("_sep=x"), "(_sep = x)");
        // Lowest precedence + right-associative.
        assert_eq!(render("a=b=c"), "(a = (b = c))");
        // Assignment is a statement value; a program can read it back.
        let ops = ladder();
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();
        let prog = parse_program(&tokenize("k=foo;$k", &sigils).unwrap(), &ops).unwrap();
        assert_eq!(prog.render(), "(k = foo); $k");
        // A non-literal-key target is an error.
        assert!(parse_expr(&tokenize("(a)=b", &sigils).unwrap(), &ops).is_err());
    }
}
