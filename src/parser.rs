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

use crate::config::{Assoc, Fixity, OperatorConfig};
use crate::lexer::{MessageRole, Token};
use crate::value::Value;

/// Default operator priority when the config leaves it unset. Per SPEC's
/// precedence ladder the default is per-fixity so the coarse ordering holds
/// without every config setting explicit priorities: prefix binds above binary,
/// which binds above the loose postfix. The finer binary ladder
/// (`**` > `* /` > `+ -`) is achieved by setting explicit config priorities.
pub const DEFAULT_PRIORITY: i64 = 9;
/// The `^` message index binds tightest (SPEC precedence ladder: `^` = 20).
pub const CARET_PRIORITY: i64 = 20;
/// Form-application `%` binding priority (bd-5dd86f): binds tighter than every
/// config operator + prefix (so `~f%x` = `~(f%x)`, `f%x+1` = `(f%x)+1`), looser
/// than the tightest `^` message read.
pub const APPLY_PRIORITY: i64 = 18;

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
    /// A quoted literal's content plus whether it interpolates bare `$name` at
    /// eval time (`true` for `"…"`, `false` for raw `'…'`).
    Quoted { content: String, interpolate: bool },
    /// `$name` — a context read.
    ContextRead(String),
    /// `$` — peek the stack top.
    StackPeek,
    /// `$N` / `$-N` — peek the stack by index.
    StackIndex(i64),
    /// `^`/`^_`/`^*`/`^/` message index over the given index expression.
    Message { role: MessageRole, index: Box<Expr> },
    /// `M^N` message-range: the messages of `role` from index `start` to `end`,
    /// joined with `_sep` (SPEC §Messages, bd-c3fc30). Infix `^` between two
    /// index expressions; prefix `^N` is [`Expr::Message`].
    MessageRange {
        role: MessageRole,
        start: Box<Expr>,
        end: Box<Expr>,
    },
    /// A parenthesised sub-expression (parens are preserved in output).
    Group(Box<Expr>),
    /// A quoted form `{…}` (bd-5dd86f): the enclosed expression captured as data
    /// (a `Value::Form`) rather than evaluated. `{a+b}` is the FORM; `(a+b)` is
    /// the value. Application (`%`) evaluates it with `$N` bound to the args.
    Quote(Box<Expr>),
    /// Form application `form % args` (bd-5dd86f): evaluate `form` to a
    /// `Value::Form`, bind `$0/$1/…` to the evaluated `args`, and evaluate the
    /// form's body under that argument frame. A List `args` (from `[x,y]` or a
    /// `(x,y)` tuple) spreads to multiple arguments.
    FormApply {
        /// The expression that must evaluate to a `Value::Form`.
        form: Box<Expr>,
        /// The argument expressions, bound to `$0/$1/…` at application.
        args: Vec<Expr>,
    },
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
    /// A reduced value spliced back into the tree by the small-step evaluator
    /// (`nlir step` / REPL step-through, bd-9c366d): an already-evaluated
    /// [`Value`] standing in for a sub-expression that has been reduced, so the
    /// surrounding expression can keep reducing one redex at a time. The parser
    /// never emits this variant; only [`crate::eval::Evaluator::step_once`] does.
    Value(Value),
}

impl Expr {
    /// A structural, fully-parenthesised rendering used for the AST dump / tests.
    #[must_use]
    pub fn render(&self) -> String {
        match self {
            // A reduced value: rendered in guillemets so a partially-reduced
            // expression visibly distinguishes what has already been evaluated.
            Expr::Value(v) => format!("\u{ab}{v}\u{bb}"),
            Expr::Bare(s) => s.clone(),
            Expr::Quoted { content, .. } => content.clone(),
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
            Expr::MessageRange { role, start, end } => {
                format!("{}^{}{}", start.render(), role.suffix(), end.render())
            }
            Expr::Group(inner) => inner.render(),
            Expr::Quote(inner) => format!("{{{}}}", inner.render()),
            Expr::FormApply { form, args } => match args.as_slice() {
                [a] => format!("({} % {})", form.render(), a.render()),
                _ => {
                    let parts: Vec<String> = args.iter().map(Expr::render).collect();
                    format!("({} % [{}])", form.render(), parts.join(", "))
                }
            },
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

    /// A reader-friendly rendering for step-through display (bd-9c366d): like
    /// [`Expr::render`] but without the single redundant outermost parenthesis
    /// pair the structural AST dump wraps compound nodes in, so a
    /// mid-reduction expression reads naturally (`((2 + 3) * 4)` -> `(2 + 3) *
    /// 4`). Inner grouping is preserved — it faithfully shows evaluation order.
    #[must_use]
    pub fn render_step(&self) -> String {
        match self {
            // render() wraps these in one matched outer `(...)`; peel just that
            // pair. Inner parens (and list `[...]`) are left intact.
            Expr::Apply { .. } | Expr::Assign { .. } | Expr::Serial(_) | Expr::FormApply { .. } => {
                let full = self.render();
                full.strip_prefix('(')
                    .and_then(|s| s.strip_suffix(')'))
                    .map(str::to_owned)
                    .unwrap_or(full)
            }
            _ => self.render(),
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
    assoc: Assoc,
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
                    assoc: o.assoc,
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
        depth: 0,
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
        depth: 0,
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

/// Maximum parser recursion depth; deeper nesting returns a clean parse error
/// instead of overflowing the stack on adversarial input (fuzz-found). Kept low
/// enough that `MAX_PARSE_DEPTH` × the parser frame fits a conservative thread
/// stack (~512KB): a 256-paren input must ERROR, not overflow, on a small-stack
/// caller (wasm / spawned test threads), not just the 8MB CLI main thread
/// (bd-… — aur-0's fuzz stack-overflow find). Real nlir expressions never nest
/// anywhere near this deep.
const MAX_PARSE_DEPTH: usize = 96;

struct Parser<'a> {
    tokens: &'a [Token],
    table: &'a BTreeMap<String, OpInfo>,
    pos: usize,
    /// Current recursion depth of `expr`, bounded by [`MAX_PARSE_DEPTH`].
    depth: usize,
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
                | Token::Quoted { .. }
                | Token::ContextRead(_)
                | Token::StackPeek
                | Token::StackIndex(_)
                | Token::Message(_)
                | Token::LParen
                | Token::LBracket
                | Token::LBrace
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

    /// Pratt expression parse with a recursion-depth guard so deeply nested
    /// input (e.g. `((((…`) returns a clean error instead of overflowing the
    /// stack (fuzz-found). Delegates to [`Self::expr_inner`].
    fn expr(&mut self, min_bp: u32) -> Result<Expr, ParseError> {
        self.depth += 1;
        if self.depth > MAX_PARSE_DEPTH {
            self.depth -= 1;
            return Err(ParseError {
                position: self.pos,
                message: "expression nesting too deep".to_owned(),
            });
        }
        let result = self.expr_inner(min_bp);
        self.depth -= 1;
        result
    }

    fn expr_inner(&mut self, min_bp: u32) -> Result<Expr, ParseError> {
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
            // Infix `M^N` message-range (bd-c3fc30): a `^` marker after a value is
            // the range form; prefix `^N` is handled in nud. Binds tightest
            // (CARET_PRIORITY), matching the prefix read.
            if let Some(Token::Message(role)) = self.peek() {
                let role = *role;
                let l_bp = bp(CARET_PRIORITY);
                if l_bp < min_bp {
                    break;
                }
                self.pos += 1;
                let end = self.expr(l_bp + 1)?;
                lhs = Expr::MessageRange {
                    role,
                    start: Box::new(lhs),
                    end: Box::new(end),
                };
                continue;
            }
            // Infix `form % args` form-application (bd-5dd86f): apply the LHS form
            // to the RHS args. Binds tight (APPLY_PRIORITY), so `~f%x` = `~(f%x)`
            // and `f%x+1` = `(f%x)+1`. A List RHS (`[x,y]` or a `(x,y)` tuple)
            // spreads as multiple args; any other RHS is a single arg.
            if matches!(self.peek(), Some(Token::Percent)) {
                let l_bp = bp(APPLY_PRIORITY);
                if l_bp < min_bp {
                    break;
                }
                self.pos += 1;
                let rhs = self.expr(l_bp + 1)?;
                let args = match rhs {
                    Expr::List(items) => items,
                    other => vec![other],
                };
                lhs = Expr::FormApply {
                    form: Box::new(lhs),
                    args,
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
                    // Left-assoc recurses the right operand one bp higher so an
                    // equal-precedence op to the right breaks and groups left
                    // (`a-b-c` = `(a-b)-c`); right-assoc (e.g. `**`) recurses one
                    // bp lower so it binds and groups right (`a**b**c` =
                    // `a**(b**c)`), matching normal math (bd-df62f1). bp() doubles
                    // priority precisely to leave this ±1 room.
                    let r_min_bp = match info.assoc {
                        Assoc::Right => l_bp.saturating_sub(1),
                        Assoc::Left => l_bp + 1,
                    };
                    let rhs = self.expr(r_min_bp)?;
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
            Token::Quoted {
                content,
                interpolate,
            } => Ok(Expr::Quoted {
                content,
                interpolate,
            }),
            Token::ContextRead(s) => Ok(Expr::ContextRead(s)),
            Token::StackPeek => Ok(Expr::StackPeek),
            Token::StackIndex(n) => Ok(Expr::StackIndex(n)),
            Token::Message(role) => {
                // A bare view with no index = the whole channel: `^*` ≡ `0^*-1`,
                // `^_` ≡ `0^_-1`, `^` ≡ `0^-1`, `^/` ≡ all system. An index parses
                // only when the next token can begin one; a terminator (`;` `,`
                // `]` `)`), an operator, or end-of-input means "the full range of
                // this view". Indexed forms (`^-1`, `^0`, `^*-1`) are unchanged;
                // the infix `M^N` range is handled in the led, not here.
                let index_follows = !matches!(
                    self.peek(),
                    None | Some(Token::Semicolon)
                        | Some(Token::Comma)
                        | Some(Token::RBracket)
                        | Some(Token::RParen)
                        | Some(Token::Operator(_))
                );
                if index_follows {
                    let index = self.expr(bp(CARET_PRIORITY))?;
                    Ok(Expr::Message {
                        role,
                        index: Box::new(index),
                    })
                } else {
                    Ok(Expr::MessageRange {
                        role,
                        start: Box::new(Expr::Number(0.0)),
                        end: Box::new(Expr::Number(-1.0)),
                    })
                }
            }
            Token::LParen => {
                let first = self.expr(0)?;
                if matches!(self.tokens.get(self.pos), Some(Token::Comma)) {
                    // Comma tuple `(a, b, …)` → a List (bd-5dd86f, D3): it spreads
                    // as form-application args and reads as a tuple value.
                    let mut items = vec![first];
                    while matches!(self.tokens.get(self.pos), Some(Token::Comma)) {
                        self.pos += 1; // consume ','
                        items.push(self.expr(0)?);
                    }
                    match self.tokens.get(self.pos) {
                        Some(Token::RParen) => {
                            self.pos += 1;
                            Ok(Expr::List(items))
                        }
                        _ => Err(ParseError {
                            position: self.pos,
                            message: "expected ')'".to_owned(),
                        }),
                    }
                } else {
                    match self.tokens.get(self.pos) {
                        Some(Token::RParen) => {
                            self.pos += 1;
                            Ok(Expr::Group(Box::new(first)))
                        }
                        _ => Err(ParseError {
                            position: self.pos,
                            message: "expected ')'".to_owned(),
                        }),
                    }
                }
            }
            Token::LBracket => {
                let items = self.parse_list_items()?;
                Ok(Expr::List(items))
            }
            Token::LBrace => {
                // Form-quote `{…}` (bd-5dd86f): capture the enclosed expression as
                // data (an `Expr::Quote`, later a `Value::Form`) rather than
                // evaluating it.
                let inner = self.expr(0)?;
                match self.tokens.get(self.pos) {
                    Some(Token::RBrace) => {
                        self.pos += 1;
                        Ok(Expr::Quote(Box::new(inner)))
                    }
                    _ => Err(ParseError {
                        position: self.pos,
                        message: "expected '}'".to_owned(),
                    }),
                }
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
            (
                "pow".to_owned(),
                OperatorConfig {
                    op: "**".to_owned(),
                    fixity: Fixity::Infix,
                    priority: Some(13),
                    assoc: Assoc::Right,
                    ..OperatorConfig::default()
                },
            ),
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
    fn form_quote_wraps_in_braces_distinct_from_group() {
        // `{a+b}` (form-quote, bd-5dd86f) renders WITH braces — code-as-data;
        // `(a+b)` (group) renders without — a value. They are distinct nodes.
        assert_eq!(render("{a+b}"), "{(a + b)}");
        assert_eq!(render("(a+b)"), "(a + b)");
        // A form wraps any expression (here a message-subject op).
        assert_eq!(render("{#^-1}"), "{(# ^-1)}");
    }

    #[test]
    fn render_round_trips_faithfully() {
        // render() is a faithful (idempotent) unparser: re-parsing a rendered
        // expression yields the same render. Value::Form Display (quote-eval,
        // bd-5dd86f) relies on this — full parenthesisation preserves precedence,
        // so a second render must equal the first.
        for src in [
            "2**3**2", "1+2*3", "a-b-c", "8/4/2", "!a&b", "a|b|c", "a?", "#^-1", "^_-1", "^*",
            "^!-1", "0^*-1", "$k", "$-1", "[a,b,c]", "(1+2)*3", "#(a&b)", "!^*", "{a+b}", "{#^-1}",
            "{!a&b}", "{$k}",
        ] {
            let once = render(src);
            let twice = render(&once);
            assert_eq!(
                once, twice,
                "render not idempotent for `{src}`: `{once}` -> `{twice}`"
            );
        }
    }

    #[test]
    fn fuzz_tokenize_and_parse_never_panic() {
        // Adversarial + deterministic pseudo-random inputs must never panic the
        // lexer or parser — they return Ok/Err, and a panic here fails the test.
        // A fixed-seed xorshift corpus keeps it reproducible without a proptest
        // dependency (bd-8f). Guards against index/slice/overflow panics on
        // malformed input reaching the CLI.
        let ops = ladder();
        let sigils: Vec<String> = ops.values().map(|o| o.op.clone()).collect();

        let mut corpus: Vec<String> = vec![
            String::new(),
            " ".to_owned(),
            "\t\n\r".to_owned(),
            "((((((((((".to_owned(),
            "))))))".to_owned(),
            "[[[[[[".to_owned(),
            "]],],]".to_owned(),
            "a&&&b".to_owned(),
            "1e999999".to_owned(),
            "999999999999999999999999999999".to_owned(),
            "-----1".to_owned(),
            "$".to_owned(),
            "$$$$".to_owned(),
            "$-".to_owned(),
            "$-99999999999999999999".to_owned(),
            "^".to_owned(),
            "^^^".to_owned(),
            "^-".to_owned(),
            "``````".to_owned(),
            "a;;;;b".to_owned(),
            "\"unterminated".to_owned(),
            "'unterminated".to_owned(),
            "= = =".to_owned(),
            "=".to_owned(),
            "%%%%".to_owned(),
            "\u{1f680}&\u{1f389}?".to_owned(),
            "a".repeat(5000),
            "(".repeat(500),
            "&".repeat(500),
            "1+".repeat(500),
            "[a,".repeat(500),
        ];

        let alphabet: &[u8] = b"abc()[]&|+-*!?;=$^`_#% \t\"'.,0123456789";
        let mut state: u64 = 0x9E37_79B9_7F4A_7C15;
        let mut next = || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state
        };
        for _ in 0..3000 {
            let len = (next() % 24) as usize;
            let s: String = (0..len)
                .map(|_| alphabet[(next() as usize) % alphabet.len()] as char)
                .collect();
            corpus.push(s);
        }

        // Parse on a thread with an explicit large stack: this corpus
        // intentionally probes deep nesting (`"(".repeat(500)` etc.), which
        // recurses to MAX_PARSE_DEPTH before erroring — depth × the parser frame
        // can exceed the default ~2MB test-thread stack on some targets (aur-0's
        // fuzz stack-overflow find), so give it headroom to be deterministic
        // across runners. The depth guard still bounds real callers.
        std::thread::Builder::new()
            .stack_size(16 * 1024 * 1024)
            .spawn(move || {
                for input in &corpus {
                    // tokenize must not panic; on Ok, parse_program must not panic.
                    if let Ok(tokens) = tokenize(input, &sigils) {
                        let _ = parse_program(&tokens, &ops);
                    }
                }
            })
            .expect("spawn fuzz thread")
            .join()
            .expect("fuzz thread must not panic");
    }

    #[test]
    fn atoms_parse() {
        assert_eq!(render("foo"), "foo");
        assert_eq!(render("123"), "123");
        assert_eq!(render("$k"), "$k");
        assert_eq!(render("$-1"), "$-1");
    }

    #[test]
    fn message_range_infix_disambiguates_from_prefix() {
        // Infix `M^N` after a value is the range; prefix `^N` at expr start (or
        // under a prefix op) is a single read (bd-c3fc30).
        assert_eq!(render("0^2"), "0^2"); // range
        assert_eq!(render("^3"), "^3"); // prefix read
        assert_eq!(render("(1+2)^(3+4)"), "(1 + 2)^(3 + 4)"); // computed endpoints
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
    fn pow_is_right_associative() {
        // `**` is right-associative (bd-df62f1): `2**3**2` == `2**(3**2)` (=512),
        // not `(2**3)**2` (=64), matching normal math / Python.
        assert_eq!(render("2**3**2"), "(2 ** (3 ** 2))");
        // Regression guards (msm-0): the other infix ops stay left-associative.
        assert_eq!(render("2-3-4"), "((2 - 3) - 4)");
        assert_eq!(render("8/4/2"), "((8 / 4) / 2)");
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
    fn bare_view_defaults_to_full_range() {
        // A bare view sigil (no index) = the whole channel: `^*` ≡ `0^*-1`,
        // `^_` ≡ `0^_-1`, `^` ≡ `0^-1`. Additive: bare `^*` previously parse-errored.
        assert_eq!(render("^*"), "0^*-1");
        assert_eq!(render("^_"), "0^_-1");
        assert_eq!(render("^"), "0^-1");
        // Indexed forms are UNCHANGED (an index follows -> single message).
        assert_eq!(render("^-1"), "^-1");
        assert_eq!(render("^*-1"), "^*-1");
        assert_eq!(render("^_0"), "^_0");
        // The explicit infix range is unchanged (handled in the led).
        assert_eq!(render("0^*-1"), "0^*-1");
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
