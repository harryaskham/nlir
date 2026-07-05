//! A tiny, sandboxed shell-subset interpreter for the in-browser command-VM
//! (bd-89bcb7, nlir-wasm P6). It runs the bounded bash subset that nlir
//! `command:` operators use — enough for the shipped `_` echo op and similar
//! snippets — as **pure Rust with no host FS/network**, so it is sandboxed by
//! construction and compiles into the `nlir-wasm` crate (no Worker, no separate
//! wasm module). The native backend still shells out to real `bash`
//! ([`crate::llm::run_llm`]); this is the in-browser substitute that fills the
//! P0 `Realiser::command` seam.
//!
//! # Supported grammar
//! - statement separators `;` and newlines
//! - `NAME=value` assignment (leading assignments before a command too)
//! - expansion: `$VAR`, `${VAR}`, `${NLIR_ARGS[k]}` (the injected args array),
//!   arithmetic `$(( … ))`, command substitution `$( … )`
//! - `for VAR in WORDS; do … done`
//! - single `'…'` (literal) and double `"…"` (expanding) quotes
//! - builtins: `printf` (`%s`/`%d`/`%%` + `\n`/`\t`), `echo`, `seq` (in `$( )`),
//!   `true`/`:`
//!
//! Anything outside this subset returns a clear `command-VM: unsupported …`
//! error rather than silently mis-running (full bash is the `brush` stretch
//! tier, see `docs/design/nlir-wasm-p6-command-vm.md`).

use std::collections::HashMap;

/// Run a `command:` operator snippet against the injected `NLIR_ARGS`, returning
/// captured stdout. Pure + sandboxed (no FS/network). See the module docs for
/// the supported grammar; unsupported constructs return `Err`.
///
/// # Errors
/// Returns a `command-VM: …` message on a parse error or an unsupported
/// construct.
pub fn run_command_vm(script: &str, args: &[String]) -> Result<String, String> {
    let toks = tokenize(script)?;
    let mut i = 0;
    let stmts = parse_block(&toks, &mut i, None)?;
    let mut env = Env {
        vars: HashMap::new(),
        args: args.to_vec(),
        out: String::new(),
    };
    exec_block(&stmts, &mut env)?;
    Ok(env.out)
}

// ---- tokeniser -------------------------------------------------------------

#[derive(Debug, Clone, PartialEq)]
enum Tok {
    Word(String),
    Sep,
}

/// Split a script into words + statement separators. Quotes, `${…}`, `$(…)` and
/// `$((…))` are atomic spans that may contain spaces/`;`.
fn tokenize(src: &str) -> Result<Vec<Tok>, String> {
    let chars: Vec<char> = src.chars().collect();
    let mut i = 0;
    let mut toks = Vec::new();
    while i < chars.len() {
        let c = chars[i];
        if c == ' ' || c == '\t' {
            i += 1;
            continue;
        }
        if c == ';' || c == '\n' {
            // collapse runs of separators into one
            if !matches!(toks.last(), Some(Tok::Sep) | None) {
                toks.push(Tok::Sep);
            }
            i += 1;
            continue;
        }
        // read one word, keeping quoted / $()/${}/$(()) spans intact
        let mut word = String::new();
        while i < chars.len() {
            let c = chars[i];
            if c == ' ' || c == '\t' || c == ';' || c == '\n' {
                break;
            }
            match c {
                '\'' => {
                    let (span, ni) = read_single(&chars, i)?;
                    word.push_str(&span);
                    i = ni;
                }
                '"' => {
                    let (span, ni) = read_double(&chars, i)?;
                    word.push_str(&span);
                    i = ni;
                }
                '$' if chars.get(i + 1) == Some(&'(') => {
                    let (span, ni) = read_paren(&chars, i)?;
                    word.push_str(&span);
                    i = ni;
                }
                '$' if chars.get(i + 1) == Some(&'{') => {
                    let (span, ni) = read_brace(&chars, i)?;
                    word.push_str(&span);
                    i = ni;
                }
                _ => {
                    word.push(c);
                    i += 1;
                }
            }
        }
        toks.push(Tok::Word(word));
    }
    Ok(toks)
}

/// Read a `'…'` span (raw, quotes kept — expansion strips them). `start` is the
/// opening quote.
fn read_single(chars: &[char], start: usize) -> Result<(String, usize), String> {
    let mut i = start + 1;
    let mut s = String::from("'");
    while i < chars.len() {
        s.push(chars[i]);
        if chars[i] == '\'' {
            return Ok((s, i + 1));
        }
        i += 1;
    }
    Err("command-VM: unterminated single quote".to_owned())
}

/// Read a `"…"` span (raw, quotes kept).
fn read_double(chars: &[char], start: usize) -> Result<(String, usize), String> {
    let mut i = start + 1;
    let mut s = String::from("\"");
    while i < chars.len() {
        let c = chars[i];
        s.push(c);
        if c == '"' {
            return Ok((s, i + 1));
        }
        i += 1;
    }
    Err("command-VM: unterminated double quote".to_owned())
}

/// Read a balanced `$(…)` / `$((…))` span (raw, kept).
fn read_paren(chars: &[char], start: usize) -> Result<(String, usize), String> {
    // start points at '$', chars[start+1] == '('
    let mut i = start + 1;
    let mut depth = 0usize;
    let mut s = String::from("$");
    while i < chars.len() {
        let c = chars[i];
        s.push(c);
        if c == '(' {
            depth += 1;
        } else if c == ')' {
            depth -= 1;
            if depth == 0 {
                return Ok((s, i + 1));
            }
        }
        i += 1;
    }
    Err("command-VM: unterminated `$(`".to_owned())
}

/// Read a `${…}` span (raw, kept).
fn read_brace(chars: &[char], start: usize) -> Result<(String, usize), String> {
    let mut i = start + 1; // at '{'
    let mut s = String::from("$");
    while i < chars.len() {
        let c = chars[i];
        s.push(c);
        if c == '}' {
            return Ok((s, i + 1));
        }
        i += 1;
    }
    Err("command-VM: unterminated `${`".to_owned())
}

// ---- parser ----------------------------------------------------------------

#[derive(Debug, Clone)]
enum Stmt {
    Assign(Vec<(String, String)>),
    For {
        var: String,
        words: Vec<String>,
        body: Vec<Stmt>,
    },
    Command {
        assigns: Vec<(String, String)>,
        name: String,
        args: Vec<String>,
    },
}

/// Parse statements until `end_kw` (consuming it) or end of input.
fn parse_block(toks: &[Tok], i: &mut usize, end_kw: Option<&str>) -> Result<Vec<Stmt>, String> {
    let mut stmts = Vec::new();
    loop {
        while matches!(toks.get(*i), Some(Tok::Sep)) {
            *i += 1;
        }
        match toks.get(*i) {
            None => break,
            Some(Tok::Word(w)) if end_kw == Some(w.as_str()) => {
                *i += 1;
                return Ok(stmts);
            }
            _ => stmts.push(parse_one(toks, i)?),
        }
    }
    if let Some(kw) = end_kw {
        return Err(format!("command-VM: missing `{kw}`"));
    }
    Ok(stmts)
}

fn parse_one(toks: &[Tok], i: &mut usize) -> Result<Stmt, String> {
    if let Some(Tok::Word(w)) = toks.get(*i) {
        if w == "for" {
            return parse_for(toks, i);
        }
        if w == "do" || w == "done" || w == "in" {
            return Err(format!("command-VM: unexpected `{w}`"));
        }
    }
    parse_simple(toks, i)
}

fn parse_simple(toks: &[Tok], i: &mut usize) -> Result<Stmt, String> {
    let mut words = Vec::new();
    while let Some(Tok::Word(w)) = toks.get(*i) {
        words.push(w.clone());
        *i += 1;
    }
    let mut assigns = Vec::new();
    let mut idx = 0;
    while idx < words.len() {
        if let Some((name, val)) = split_assign(&words[idx]) {
            assigns.push((name, val));
            idx += 1;
        } else {
            break;
        }
    }
    if idx == words.len() {
        Ok(Stmt::Assign(assigns))
    } else {
        Ok(Stmt::Command {
            assigns,
            name: words[idx].clone(),
            args: words[idx + 1..].to_vec(),
        })
    }
}

fn parse_for(toks: &[Tok], i: &mut usize) -> Result<Stmt, String> {
    *i += 1; // 'for'
    let var = match toks.get(*i) {
        Some(Tok::Word(w)) => w.clone(),
        _ => return Err("command-VM: `for` needs a variable".to_owned()),
    };
    *i += 1;
    match toks.get(*i) {
        Some(Tok::Word(w)) if w == "in" => *i += 1,
        _ => return Err("command-VM: `for` needs `in`".to_owned()),
    }
    let mut words = Vec::new();
    loop {
        match toks.get(*i) {
            Some(Tok::Word(w)) if w == "do" => {
                *i += 1;
                break;
            }
            Some(Tok::Word(w)) => {
                words.push(w.clone());
                *i += 1;
            }
            Some(Tok::Sep) => *i += 1,
            None => return Err("command-VM: `for` missing `do`".to_owned()),
        }
    }
    let body = parse_block(toks, i, Some("done"))?;
    Ok(Stmt::For { var, words, body })
}

/// If `word` starts with `NAME=`, split into `(name, raw-value)`.
fn split_assign(word: &str) -> Option<(String, String)> {
    let eq = word.find('=')?;
    let name = &word[..eq];
    if name.is_empty() {
        return None;
    }
    let mut cs = name.chars();
    let first = cs.next()?;
    if !(first.is_ascii_alphabetic() || first == '_') {
        return None;
    }
    if !cs.all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return None;
    }
    Some((name.to_owned(), word[eq + 1..].to_owned()))
}

// ---- executor --------------------------------------------------------------

struct Env {
    vars: HashMap<String, String>,
    args: Vec<String>,
    out: String,
}

fn exec_block(stmts: &[Stmt], env: &mut Env) -> Result<(), String> {
    for s in stmts {
        exec_stmt(s, env)?;
    }
    Ok(())
}

fn exec_stmt(s: &Stmt, env: &mut Env) -> Result<(), String> {
    match s {
        Stmt::Assign(assigns) => {
            for (name, raw) in assigns {
                let val = expand(raw, env)?;
                env.vars.insert(name.clone(), val);
            }
            Ok(())
        }
        Stmt::For { var, words, body } => {
            let mut items = Vec::new();
            for w in words {
                let expanded = expand(w, env)?;
                items.extend(expanded.split_whitespace().map(str::to_owned));
            }
            for item in items {
                env.vars.insert(var.clone(), item);
                exec_block(body, env)?;
            }
            Ok(())
        }
        Stmt::Command {
            assigns,
            name,
            args,
        } => {
            for (n, raw) in assigns {
                let v = expand(raw, env)?;
                env.vars.insert(n.clone(), v);
            }
            let ename = expand(name, env)?;
            let mut eargs = Vec::with_capacity(args.len());
            for a in args {
                eargs.push(expand(a, env)?);
            }
            run_builtin(&ename, &eargs, env)
        }
    }
}

fn run_builtin(name: &str, args: &[String], env: &mut Env) -> Result<(), String> {
    match name {
        "printf" => {
            let rendered = do_printf(args)?;
            env.out.push_str(&rendered);
            Ok(())
        }
        "echo" => {
            env.out.push_str(&args.join(" "));
            env.out.push('\n');
            Ok(())
        }
        "true" | ":" => Ok(()),
        other => Err(format!("command-VM: unsupported command `{other}`")),
    }
}

/// `printf FMT ARGS…` — supports `%s`, `%d`, `%%`, and `\n`/`\t` escapes.
fn do_printf(args: &[String]) -> Result<String, String> {
    let fmt = args
        .first()
        .ok_or("command-VM: printf needs a format")?
        .clone();
    let rest = &args[1..];
    let mut out = String::new();
    let mut ai = 0;
    let mut cs = fmt.chars().peekable();
    while let Some(c) = cs.next() {
        match c {
            '%' => match cs.next() {
                Some('s') => {
                    out.push_str(rest.get(ai).map_or("", String::as_str));
                    ai += 1;
                }
                Some('d') => {
                    out.push_str(rest.get(ai).map_or("0", String::as_str));
                    ai += 1;
                }
                Some('%') => out.push('%'),
                Some(other) => {
                    out.push('%');
                    out.push(other);
                }
                None => out.push('%'),
            },
            '\\' => match cs.next() {
                Some('n') => out.push('\n'),
                Some('t') => out.push('\t'),
                Some(other) => out.push(other),
                None => out.push('\\'),
            },
            _ => out.push(c),
        }
    }
    Ok(out)
}

// ---- expansion -------------------------------------------------------------

/// Expand a raw word (quotes, `$VAR`, `${…}`, `$(( ))`, `$( )`) to its value.
fn expand(word: &str, env: &Env) -> Result<String, String> {
    let chars: Vec<char> = word.chars().collect();
    let mut i = 0;
    let mut out = String::new();
    while i < chars.len() {
        match chars[i] {
            '\'' => {
                // literal until next '
                i += 1;
                while i < chars.len() && chars[i] != '\'' {
                    out.push(chars[i]);
                    i += 1;
                }
                i += 1; // closing '
            }
            '"' => {
                i += 1;
                while i < chars.len() && chars[i] != '"' {
                    if chars[i] == '$' {
                        let (val, ni) = expand_dollar(&chars, i, env)?;
                        out.push_str(&val);
                        i = ni;
                    } else {
                        out.push(chars[i]);
                        i += 1;
                    }
                }
                i += 1; // closing "
            }
            '$' => {
                let (val, ni) = expand_dollar(&chars, i, env)?;
                out.push_str(&val);
                i = ni;
            }
            c => {
                out.push(c);
                i += 1;
            }
        }
    }
    Ok(out)
}

/// Expand a `$…` starting at `chars[i]=='$'`; returns the value + next index.
fn expand_dollar(chars: &[char], i: usize, env: &Env) -> Result<(String, usize), String> {
    // $(( arith ))
    if chars.get(i + 1) == Some(&'(') && chars.get(i + 2) == Some(&'(') {
        let (span, ni) = read_paren(chars, i)?; // $(( … ))
        let inner = span[3..span.len() - 2].to_owned(); // strip $(( and ))
        let v = eval_arith(&inner, env)?;
        return Ok((v.to_string(), ni));
    }
    // $( cmd )
    if chars.get(i + 1) == Some(&'(') {
        let (span, ni) = read_paren(chars, i)?; // $( … )
        let inner = span[2..span.len() - 1].to_owned(); // strip $( and )
        let v = command_sub(&inner, env)?;
        return Ok((v, ni));
    }
    // ${ … }
    if chars.get(i + 1) == Some(&'{') {
        let (span, ni) = read_brace(chars, i)?;
        let inner = span[2..span.len() - 1].to_owned(); // strip ${ and }
        let v = expand_param(&inner, env)?;
        return Ok((v, ni));
    }
    // $VAR (bare identifier)
    let mut j = i + 1;
    let mut name = String::new();
    while j < chars.len() && (chars[j].is_ascii_alphanumeric() || chars[j] == '_') {
        name.push(chars[j]);
        j += 1;
    }
    if name.is_empty() {
        return Ok(("$".to_owned(), i + 1)); // lone $
    }
    Ok((env.vars.get(&name).cloned().unwrap_or_default(), j))
}

/// Expand a `${…}` body: `VAR` or `NLIR_ARGS[k]`.
fn expand_param(inner: &str, env: &Env) -> Result<String, String> {
    if let Some(rest) = inner.strip_prefix("NLIR_ARGS[") {
        let idx = rest
            .strip_suffix(']')
            .ok_or("command-VM: malformed ${NLIR_ARGS[…]}")?;
        let k: usize = idx
            .trim()
            .parse()
            .map_err(|_| format!("command-VM: bad NLIR_ARGS index `{idx}`"))?;
        return Ok(env.args.get(k).cloned().unwrap_or_default());
    }
    if inner.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return Ok(env.vars.get(inner).cloned().unwrap_or_default());
    }
    Err(format!("command-VM: unsupported ${{{inner}}}"))
}

/// Run a `$( … )` command substitution (a sub-shell over the shared vars/args)
/// and return its stdout with trailing newlines stripped. `seq` is available
/// here as a builtin.
fn command_sub(inner: &str, env: &Env) -> Result<String, String> {
    // seq A B / seq N — the one command-sub builtin the shipped grammar uses.
    let toks = tokenize(inner)?;
    let words: Vec<String> = toks
        .iter()
        .filter_map(|t| match t {
            Tok::Word(w) => Some(w.clone()),
            Tok::Sep => None,
        })
        .collect();
    if let Some(first) = words.first() {
        let name = expand(first, env)?;
        if name == "seq" {
            let nums: Result<Vec<i64>, String> = words[1..]
                .iter()
                .map(|w| {
                    let v = expand(w, env)?;
                    v.trim()
                        .parse::<i64>()
                        .map_err(|_| format!("command-VM: seq needs integers, got `{v}`"))
                })
                .collect();
            let nums = nums?;
            let (lo, hi) = match nums.as_slice() {
                [n] => (1, *n),
                [a, b] => (*a, *b),
                _ => return Err("command-VM: seq takes 1 or 2 integer args".to_owned()),
            };
            let mut out = String::new();
            let mut k = lo;
            while k <= hi {
                out.push_str(&k.to_string());
                out.push('\n');
                k += 1;
            }
            return Ok(out.trim_end_matches('\n').to_owned());
        }
    }
    // General fallback: run the inner as a sub-shell and capture its stdout.
    let mut i = 0;
    let stmts = parse_block(&toks, &mut i, None)?;
    let mut sub = Env {
        vars: env.vars.clone(),
        args: env.args.clone(),
        out: String::new(),
    };
    exec_block(&stmts, &mut sub)?;
    Ok(sub.out.trim_end_matches('\n').to_owned())
}

// ---- arithmetic ($(( … ))) -------------------------------------------------

/// Evaluate a `$(( … ))` integer expression. Bare identifiers resolve to
/// variables (default 0), as in bash arithmetic.
fn eval_arith(expr: &str, env: &Env) -> Result<i64, String> {
    let toks = arith_tokens(expr)?;
    let mut p = ArithParser {
        toks: &toks,
        i: 0,
        env,
    };
    let v = p.expr()?;
    if p.i != p.toks.len() {
        return Err(format!("command-VM: trailing tokens in `$(( {expr} ))`"));
    }
    Ok(v)
}

#[derive(Debug, Clone, PartialEq)]
enum At {
    Num(i64),
    Ident(String),
    Op(char),
    LParen,
    RParen,
}

fn arith_tokens(expr: &str) -> Result<Vec<At>, String> {
    let chars: Vec<char> = expr.chars().collect();
    let mut i = 0;
    let mut toks = Vec::new();
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
        } else if c.is_ascii_digit() {
            let mut n = 0i64;
            while i < chars.len() && chars[i].is_ascii_digit() {
                n = n * 10 + (chars[i] as i64 - '0' as i64);
                i += 1;
            }
            toks.push(At::Num(n));
        } else if c.is_ascii_alphabetic() || c == '_' {
            let mut s = String::new();
            while i < chars.len() && (chars[i].is_ascii_alphanumeric() || chars[i] == '_') {
                s.push(chars[i]);
                i += 1;
            }
            toks.push(At::Ident(s));
        } else if c == '$' {
            // $var inside arithmetic — treat like a bare identifier
            i += 1;
        } else if "+-*/%".contains(c) {
            toks.push(At::Op(c));
            i += 1;
        } else if c == '(' {
            toks.push(At::LParen);
            i += 1;
        } else if c == ')' {
            toks.push(At::RParen);
            i += 1;
        } else {
            return Err(format!("command-VM: bad char `{c}` in arithmetic"));
        }
    }
    Ok(toks)
}

struct ArithParser<'a> {
    toks: &'a [At],
    i: usize,
    env: &'a Env,
}

impl ArithParser<'_> {
    fn expr(&mut self) -> Result<i64, String> {
        let mut v = self.term()?;
        while let Some(At::Op(op @ ('+' | '-'))) = self.toks.get(self.i) {
            let op = *op;
            self.i += 1;
            let r = self.term()?;
            v = if op == '+' { v + r } else { v - r };
        }
        Ok(v)
    }

    fn term(&mut self) -> Result<i64, String> {
        let mut v = self.factor()?;
        while let Some(At::Op(op @ ('*' | '/' | '%'))) = self.toks.get(self.i) {
            let op = *op;
            self.i += 1;
            let r = self.factor()?;
            match op {
                '*' => v *= r,
                '/' => {
                    if r == 0 {
                        return Err("command-VM: division by zero".to_owned());
                    }
                    v /= r;
                }
                _ => {
                    if r == 0 {
                        return Err("command-VM: modulo by zero".to_owned());
                    }
                    v %= r;
                }
            }
        }
        Ok(v)
    }

    fn factor(&mut self) -> Result<i64, String> {
        match self.toks.get(self.i) {
            Some(At::Num(n)) => {
                self.i += 1;
                Ok(*n)
            }
            Some(At::Ident(name)) => {
                self.i += 1;
                let raw = self.env.vars.get(name).cloned().unwrap_or_default();
                Ok(raw.trim().parse::<i64>().unwrap_or(0))
            }
            Some(At::Op('-')) => {
                self.i += 1;
                Ok(-self.factor()?)
            }
            Some(At::LParen) => {
                self.i += 1;
                let v = self.expr()?;
                match self.toks.get(self.i) {
                    Some(At::RParen) => {
                        self.i += 1;
                        Ok(v)
                    }
                    _ => Err("command-VM: unbalanced `(` in arithmetic".to_owned()),
                }
            }
            _ => Err("command-VM: unexpected end of arithmetic expression".to_owned()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(script: &str, args: &[&str]) -> Result<String, String> {
        let args: Vec<String> = args.iter().map(|s| (*s).to_owned()).collect();
        run_command_vm(script, &args)
    }

    /// The shipped `_` echo op — the P6 acceptance case.
    const ECHO: &str = "t=\"${NLIR_ARGS[0]}\"; n=\"${NLIR_ARGS[1]}\"; out=\"$t\"\n\
        for i in $(seq 1 $((n-1))); do out=\"$out $t\"; done\n\
        printf '%s' \"$out\"";

    #[test]
    fn echo_op_repeats_text() {
        assert_eq!(run(ECHO, &["x", "2"]).unwrap(), "x x");
        assert_eq!(run(ECHO, &["x", "3"]).unwrap(), "x x x");
        assert_eq!(run(ECHO, &["hi", "1"]).unwrap(), "hi");
        assert_eq!(run(ECHO, &["ab", "4"]).unwrap(), "ab ab ab ab");
    }

    #[test]
    fn assignment_and_expansion() {
        assert_eq!(run("a=hi; printf '%s' \"$a\"", &[]).unwrap(), "hi");
        assert_eq!(run("printf '%s' \"${NLIR_ARGS[0]}\"", &["z"]).unwrap(), "z");
    }

    #[test]
    fn arithmetic_and_seq() {
        assert_eq!(run("printf '%d' \"$((2+3*4))\"", &[]).unwrap(), "14");
        assert_eq!(run("printf '%d' \"$(((2+3)*4))\"", &[]).unwrap(), "20");
        assert_eq!(run("n=5; printf '%d' \"$((n-1))\"", &[]).unwrap(), "4");
    }

    #[test]
    fn for_loop_over_command_sub() {
        // sum-ish: concatenate seq output
        assert_eq!(
            run(
                "out=; for i in $(seq 1 3); do out=\"$out$i\"; done; printf '%s' \"$out\"",
                &[]
            )
            .unwrap(),
            "123"
        );
    }

    #[test]
    fn echo_builtin_and_printf_escapes() {
        assert_eq!(run("echo hello world", &[]).unwrap(), "hello world\n");
        assert_eq!(run("printf 'a\\tb\\n'", &[]).unwrap(), "a\tb\n");
        assert_eq!(run("printf '100%%'", &[]).unwrap(), "100%");
    }

    #[test]
    fn unsupported_command_errors_clearly() {
        let err = run("rm -rf /", &[]).unwrap_err();
        assert!(err.contains("unsupported command"), "{err}");
    }
}
