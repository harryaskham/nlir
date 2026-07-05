//! The `nlir tui` full-screen workbench (bd-ae1730): a session browser + context
//! manager + live expression workbench, the terminal sibling of the browser
//! workspace. This module holds the **pure** workbench state (focus, list
//! selections, the expression editor, and the last eval output) plus the ratatui
//! rendering; all IO — config/context resolution, evaluation, and the shared
//! session pool (`sessions_dir`/`list_sessions`/`restore_session`/
//! `archive_session`, shared with `nlir repl`) — lives in `main.rs` and drives
//! this state. Keeping navigation/selection logic side-effect-free makes it
//! unit-testable without a terminal.

use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Position, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};

use crate::line_editor::LineEditor;

/// The three focusable panes, in Tab-cycle order.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Pane {
    /// The expression editor (right-top).
    Expr,
    /// The session browser (left-top).
    Sessions,
    /// The context key/value viewer (left-bottom).
    Context,
}

impl Pane {
    /// Next pane in Tab order: Expr -> Sessions -> Context -> Expr.
    fn next(self) -> Self {
        match self {
            Pane::Expr => Pane::Sessions,
            Pane::Sessions => Pane::Context,
            Pane::Context => Pane::Expr,
        }
    }

    /// Previous pane (Shift-Tab).
    fn prev(self) -> Self {
        match self {
            Pane::Expr => Pane::Context,
            Pane::Sessions => Pane::Expr,
            Pane::Context => Pane::Sessions,
        }
    }
}

/// One saved-session row in the browser: the pool file plus its one-line summary.
#[derive(Debug, Clone)]
pub struct SessionEntry {
    pub path: std::path::PathBuf,
    pub summary: String,
}

/// One context key/value row (value already rendered for display).
#[derive(Debug, Clone)]
pub struct ContextEntry {
    pub key: String,
    pub value: String,
}

/// What an active modal edit will commit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EditKind {
    /// Replace the value of an existing context key.
    Value,
    /// Add a new `key=value` context entry.
    NewEntry,
}

/// An in-progress modal edit over the context (value edit or new entry).
pub struct EditState {
    pub kind: EditKind,
    /// The key being edited (`Value`); `None` for a `NewEntry`.
    pub key: Option<String>,
    /// Prompt shown in the modal.
    pub prompt: String,
    /// The line editor for the modal input.
    pub editor: LineEditor,
}

/// The pure workbench state. `main.rs` mutates it via the methods here and reads
/// it back to render; it performs no IO itself.
pub struct Workbench {
    focus: Pane,
    sessions: Vec<SessionEntry>,
    session_sel: usize,
    context: Vec<ContextEntry>,
    context_sel: usize,
    /// The expression editor (shared line-edit core with the ratatui REPL work).
    pub editor: LineEditor,
    /// Rendered result / error of the last evaluation.
    output: String,
    output_is_error: bool,
    /// Transient status-line message (last action outcome).
    status: String,
    should_quit: bool,
    /// An active modal context edit, if any (mutually exclusive with pane input).
    editing: Option<EditState>,
}

impl Workbench {
    /// Build a workbench from the initial session-pool + context snapshots.
    pub fn new(sessions: Vec<SessionEntry>, context: Vec<ContextEntry>) -> Self {
        Self {
            focus: Pane::Expr,
            sessions,
            session_sel: 0,
            context,
            context_sel: 0,
            editor: LineEditor::new(),
            output: String::new(),
            output_is_error: false,
            status: "Tab switches pane · Enter evaluates / restores · Ctrl-D or Esc quits"
                .to_owned(),
            should_quit: false,
            editing: None,
        }
    }

    pub fn focus(&self) -> Pane {
        self.focus
    }

    pub fn should_quit(&self) -> bool {
        self.should_quit
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    /// Move focus to the next / previous pane (Tab / Shift-Tab).
    pub fn focus_next(&mut self) {
        self.focus = self.focus.next();
    }
    pub fn focus_prev(&mut self) {
        self.focus = self.focus.prev();
    }

    /// Move the selection up in the focused list pane (Sessions/Context).
    pub fn list_up(&mut self) {
        match self.focus {
            Pane::Sessions => self.session_sel = self.session_sel.saturating_sub(1),
            Pane::Context => self.context_sel = self.context_sel.saturating_sub(1),
            Pane::Expr => {}
        }
    }

    /// Move the selection down in the focused list pane (Sessions/Context).
    pub fn list_down(&mut self) {
        match self.focus {
            Pane::Sessions => {
                if self.session_sel + 1 < self.sessions.len() {
                    self.session_sel += 1;
                }
            }
            Pane::Context => {
                if self.context_sel + 1 < self.context.len() {
                    self.context_sel += 1;
                }
            }
            Pane::Expr => {}
        }
    }

    /// The session file currently selected in the browser, if any.
    pub fn selected_session(&self) -> Option<&SessionEntry> {
        self.sessions.get(self.session_sel)
    }

    /// Replace the session list (after a restore/refresh), clamping the cursor.
    pub fn set_sessions(&mut self, sessions: Vec<SessionEntry>) {
        self.sessions = sessions;
        self.session_sel = self.session_sel.min(self.sessions.len().saturating_sub(1));
    }

    /// Replace the context rows (after eval/restore), clamping the cursor.
    pub fn set_context(&mut self, context: Vec<ContextEntry>) {
        self.context = context;
        self.context_sel = self.context_sel.min(self.context.len().saturating_sub(1));
    }

    /// Record the outcome of an evaluation for the Output pane.
    pub fn set_output(&mut self, result: Result<String, String>) {
        match result {
            Ok(value) => {
                self.output = value;
                self.output_is_error = false;
            }
            Err(error) => {
                self.output = error;
                self.output_is_error = true;
            }
        }
    }

    /// Set the transient status-line message.
    pub fn set_status(&mut self, status: impl Into<String>) {
        self.status = status.into();
    }

    /// The context row currently selected in the Context pane, if any.
    pub fn selected_context(&self) -> Option<&ContextEntry> {
        self.context.get(self.context_sel)
    }

    /// Whether a modal context edit is active (input goes to the modal, not panes).
    pub fn is_editing(&self) -> bool {
        self.editing.is_some()
    }

    /// The active edit state, for rendering the modal.
    pub fn editing(&self) -> Option<&EditState> {
        self.editing.as_ref()
    }

    /// Mutable access to the modal editor, for routing key presses.
    pub fn edit_editor_mut(&mut self) -> Option<&mut LineEditor> {
        self.editing.as_mut().map(|state| &mut state.editor)
    }

    /// Begin editing an existing context key's value, prefilling the current one.
    pub fn begin_value_edit(&mut self, key: String, current: String) {
        let mut editor = LineEditor::new();
        editor.insert_str(&current);
        self.editing = Some(EditState {
            kind: EditKind::Value,
            prompt: format!("edit  {key} ="),
            key: Some(key),
            editor,
        });
    }

    /// Begin adding a new `key=value` context entry.
    pub fn begin_new_entry(&mut self) {
        self.editing = Some(EditState {
            kind: EditKind::NewEntry,
            prompt: "new entry  (key=value)".to_owned(),
            key: None,
            editor: LineEditor::new(),
        });
    }

    /// Cancel the active modal edit (Esc), discarding input.
    pub fn cancel_edit(&mut self) {
        self.editing = None;
    }

    /// Commit the active modal edit, returning its kind, target key, and the
    /// typed input, and clearing the modal. `None` if nothing is being edited.
    pub fn commit_edit(&mut self) -> Option<(EditKind, Option<String>, String)> {
        let state = self.editing.take()?;
        Some((state.kind, state.key, state.editor.buffer_string()))
    }
}

/// Draw the whole workbench for one frame.
pub fn render(frame: &mut Frame, wb: &Workbench) {
    let area = frame.area();
    // help bar (2) · body (min) · status (1)
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2),
            Constraint::Min(3),
            Constraint::Length(1),
        ])
        .split(area);
    render_help(frame, rows[0], wb);

    // body: left column (sessions/context) · right column (expr/output)
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(34), Constraint::Min(20)])
        .split(rows[1]);
    let left = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(55), Constraint::Percentage(45)])
        .split(cols[0]);
    let right = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(3)])
        .split(cols[1]);

    render_sessions(frame, left[0], wb);
    render_context(frame, left[1], wb);
    render_expr(frame, right[0], wb);
    render_output(frame, right[1], wb);
    render_status(frame, rows[2], wb);

    // A modal context edit floats above the panes.
    if wb.is_editing() {
        render_edit_modal(frame, area, wb);
    }
}

fn pane_block(title: &str, focused: bool) -> Block<'_> {
    let border_style = if focused {
        Style::default()
            .fg(Color::Yellow)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(Color::DarkGray)
    };
    let title_style = if focused {
        Style::default()
            .fg(Color::Yellow)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(Color::Gray)
    };
    Block::default()
        .borders(Borders::ALL)
        .border_style(border_style)
        .title(Span::styled(format!(" {title} "), title_style))
}

fn render_help(frame: &mut Frame, area: Rect, wb: &Workbench) {
    let line1 = Line::from(vec![
        Span::styled(
            "nlir workbench",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw("  —  "),
        Span::styled("Tab", Style::default().fg(Color::Yellow)),
        Span::raw(" pane · "),
        Span::styled("Enter", Style::default().fg(Color::Yellow)),
        Span::raw(" eval/restore · "),
        Span::styled("Ctrl-D/Esc", Style::default().fg(Color::Yellow)),
        Span::raw(" quit"),
    ]);
    let hint = match wb.focus() {
        Pane::Expr => "Expression: type · Enter evaluates · ↑↓ history · Ctrl-A/E/K/U/W edit",
        Pane::Sessions => "Sessions: ↑↓ select · Enter restores into the context",
        Pane::Context => "Context: ↑↓ select · e edit · a add · d delete",
    };
    let line2 = Line::from(Span::styled(hint, Style::default().fg(Color::DarkGray)));
    frame.render_widget(Paragraph::new(vec![line1, line2]), area);
}

fn render_sessions(frame: &mut Frame, area: Rect, wb: &Workbench) {
    let focused = wb.focus == Pane::Sessions;
    let items: Vec<ListItem> = if wb.sessions.is_empty() {
        vec![ListItem::new(Span::styled(
            "(no saved sessions)",
            Style::default().fg(Color::DarkGray),
        ))]
    } else {
        wb.sessions
            .iter()
            .map(|s| ListItem::new(Line::from(s.summary.clone())))
            .collect()
    };
    let list = List::new(items)
        .block(pane_block("Sessions", focused))
        .highlight_style(
            Style::default()
                .bg(Color::Blue)
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("▶ ");
    let mut state = ListState::default();
    if !wb.sessions.is_empty() {
        state.select(Some(wb.session_sel.min(wb.sessions.len() - 1)));
    }
    frame.render_stateful_widget(list, area, &mut state);
}

fn render_context(frame: &mut Frame, area: Rect, wb: &Workbench) {
    let focused = wb.focus == Pane::Context;
    let items: Vec<ListItem> = if wb.context.is_empty() {
        vec![ListItem::new(Span::styled(
            "(empty context)",
            Style::default().fg(Color::DarkGray),
        ))]
    } else {
        wb.context
            .iter()
            .map(|entry| {
                ListItem::new(Line::from(vec![
                    Span::styled(entry.key.clone(), Style::default().fg(Color::Green)),
                    Span::raw(" = "),
                    Span::raw(entry.value.clone()),
                ]))
            })
            .collect()
    };
    let list = List::new(items)
        .block(pane_block("Context", focused))
        .highlight_style(Style::default().bg(Color::Blue).fg(Color::White))
        .highlight_symbol("▶ ");
    let mut state = ListState::default();
    if !wb.context.is_empty() {
        state.select(Some(wb.context_sel.min(wb.context.len() - 1)));
    }
    frame.render_stateful_widget(list, area, &mut state);
}

fn render_expr(frame: &mut Frame, area: Rect, wb: &Workbench) {
    let focused = wb.focus == Pane::Expr;
    let block = pane_block("Expression", focused);
    let inner = block.inner(area);
    let prompt = "» ";
    let prompt_w = prompt.chars().count();
    let buffer = wb.editor.buffer_string();
    let width = inner.width.max(1) as usize;
    let cursor_col = prompt_w + wb.editor.cursor();
    let scroll = cursor_col.saturating_sub(width.saturating_sub(1)) as u16;
    let text = format!("{prompt}{buffer}");
    frame.render_widget(Paragraph::new(text).block(block).scroll((0, scroll)), area);
    if focused && inner.width > 0 && inner.height > 0 {
        let x = inner.x + (cursor_col as u16).saturating_sub(scroll);
        frame.set_cursor_position(Position {
            x: x.min(inner.x + inner.width - 1),
            y: inner.y,
        });
    }
}

fn render_output(frame: &mut Frame, area: Rect, wb: &Workbench) {
    let focused = wb.focus == Pane::Expr; // output tracks the expr pane
    let style = if wb.output_is_error {
        Style::default().fg(Color::Red)
    } else {
        Style::default().fg(Color::White)
    };
    let body = if wb.output.is_empty() {
        Span::styled(
            "(evaluate an expression — deterministic mode)",
            Style::default().fg(Color::DarkGray),
        )
    } else {
        Span::styled(wb.output.clone(), style)
    };
    frame.render_widget(
        Paragraph::new(Line::from(body))
            .block(pane_block("Output", focused))
            .wrap(Wrap { trim: false }),
        area,
    );
}

fn render_status(frame: &mut Frame, area: Rect, wb: &Workbench) {
    frame.render_widget(
        Paragraph::new(Span::styled(
            wb.status.clone(),
            Style::default().fg(Color::DarkGray),
        )),
        area,
    );
}

/// Draw the modal context-edit box (value edit or new entry) over the panes.
fn render_edit_modal(frame: &mut Frame, area: Rect, wb: &Workbench) {
    let Some(state) = wb.editing() else {
        return;
    };
    let modal = centered_fixed(area, 70, 6);
    frame.render_widget(Clear, modal);
    let title = match state.kind {
        EditKind::Value => " Edit context value ",
        EditKind::NewEntry => " New context entry ",
    };
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(
            Style::default()
                .fg(Color::Magenta)
                .add_modifier(Modifier::BOLD),
        )
        .title(Span::styled(
            title,
            Style::default()
                .fg(Color::Magenta)
                .add_modifier(Modifier::BOLD),
        ));
    let inner = block.inner(modal);
    frame.render_widget(block, modal);
    if inner.height < 2 {
        return;
    }
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Min(0),
            Constraint::Length(1),
        ])
        .split(inner);
    frame.render_widget(
        Paragraph::new(Span::styled(
            state.prompt.clone(),
            Style::default().fg(Color::Gray),
        )),
        rows[0],
    );
    let prompt = "» ";
    let buffer = state.editor.buffer_string();
    let width = rows[1].width.max(1) as usize;
    let cursor_col = prompt.chars().count() + state.editor.cursor();
    let scroll = cursor_col.saturating_sub(width.saturating_sub(1)) as u16;
    frame.render_widget(
        Paragraph::new(format!("{prompt}{buffer}")).scroll((0, scroll)),
        rows[1],
    );
    frame.render_widget(
        Paragraph::new(Span::styled(
            "Enter: save · Esc: cancel",
            Style::default().fg(Color::DarkGray),
        )),
        rows[3],
    );
    let x = rows[1].x + (cursor_col as u16).saturating_sub(scroll);
    frame.set_cursor_position(Position {
        x: x.min(rows[1].x + rows[1].width.saturating_sub(1)),
        y: rows[1].y,
    });
}

/// A fixed-size rectangle centered within `area`, clamped to fit.
fn centered_fixed(area: Rect, width: u16, height: u16) -> Rect {
    let width = width.min(area.width);
    let height = height.min(area.height);
    Rect {
        x: area.x + area.width.saturating_sub(width) / 2,
        y: area.y + area.height.saturating_sub(height) / 2,
        width,
        height,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Workbench {
        let sessions = vec![
            SessionEntry {
                path: "/s/2.json".into(),
                summary: "[2] 1 msg".into(),
            },
            SessionEntry {
                path: "/s/1.json".into(),
                summary: "[1] 2 msg".into(),
            },
        ];
        let context = vec![
            ContextEntry {
                key: "greeting".into(),
                value: "hi".into(),
            },
            ContextEntry {
                key: "_messages".into(),
                value: "3 messages".into(),
            },
        ];
        Workbench::new(sessions, context)
    }

    #[test]
    fn focus_cycles_forward_and_back() {
        let mut wb = sample();
        assert_eq!(wb.focus(), Pane::Expr);
        wb.focus_next();
        assert_eq!(wb.focus(), Pane::Sessions);
        wb.focus_next();
        assert_eq!(wb.focus(), Pane::Context);
        wb.focus_next();
        assert_eq!(wb.focus(), Pane::Expr);
        wb.focus_prev();
        assert_eq!(wb.focus(), Pane::Context);
    }

    #[test]
    fn list_navigation_clamps_within_focused_pane() {
        let mut wb = sample();
        // Expr focused: list nav is a no-op.
        wb.list_down();
        assert!(wb.selected_session().is_some());
        wb.focus_next(); // Sessions
        assert_eq!(wb.selected_session().unwrap().summary, "[2] 1 msg");
        wb.list_down();
        assert_eq!(wb.selected_session().unwrap().summary, "[1] 2 msg");
        wb.list_down(); // clamp at last
        assert_eq!(wb.selected_session().unwrap().summary, "[1] 2 msg");
        wb.list_up();
        assert_eq!(wb.selected_session().unwrap().summary, "[2] 1 msg");
        wb.list_up(); // clamp at first
        assert_eq!(wb.selected_session().unwrap().summary, "[2] 1 msg");
    }

    #[test]
    fn context_selection_is_independent_of_sessions() {
        let mut wb = sample();
        wb.focus = Pane::Context;
        wb.list_down();
        assert_eq!(wb.context_sel, 1);
        wb.list_down(); // clamp
        assert_eq!(wb.context_sel, 1);
        // sessions selection untouched
        assert_eq!(wb.session_sel, 0);
    }

    #[test]
    fn set_output_ok_and_err() {
        let mut wb = sample();
        wb.set_output(Ok("Distil the reply.".into()));
        assert!(!wb.output_is_error);
        assert_eq!(wb.output, "Distil the reply.");
        wb.set_output(Err("parse error".into()));
        assert!(wb.output_is_error);
        assert_eq!(wb.output, "parse error");
    }

    #[test]
    fn set_sessions_clamps_selection() {
        let mut wb = sample();
        wb.focus = Pane::Sessions;
        wb.list_down(); // sel = 1
        wb.set_sessions(vec![SessionEntry {
            path: "/s/9.json".into(),
            summary: "[9] 0 msg".into(),
        }]);
        assert_eq!(wb.session_sel, 0);
        assert_eq!(wb.selected_session().unwrap().summary, "[9] 0 msg");
    }

    #[test]
    fn empty_pool_has_no_selected_session() {
        let wb = Workbench::new(vec![], vec![]);
        assert!(wb.selected_session().is_none());
    }

    #[test]
    fn editor_is_wired_for_expression_editing() {
        let mut wb = sample();
        wb.editor.insert_str("~@^-1");
        assert_eq!(wb.editor.buffer_string(), "~@^-1");
        let submitted = wb.editor.submit();
        assert_eq!(submitted, "~@^-1");
        assert!(wb.editor.is_empty());
    }

    #[test]
    fn selected_context_tracks_selection() {
        let mut wb = sample();
        wb.focus = Pane::Context;
        assert_eq!(wb.selected_context().unwrap().key, "greeting");
        wb.list_down();
        assert_eq!(wb.selected_context().unwrap().key, "_messages");
    }

    #[test]
    fn value_edit_lifecycle_commits_typed_input() {
        let mut wb = sample();
        assert!(!wb.is_editing());
        wb.begin_value_edit("greeting".into(), "hi".into());
        assert!(wb.is_editing());
        // prefilled with the current value
        assert_eq!(wb.editing().unwrap().editor.buffer_string(), "hi");
        // edit it
        let editor = wb.edit_editor_mut().unwrap();
        editor.end();
        editor.insert_str(" there");
        let (kind, key, input) = wb.commit_edit().unwrap();
        assert_eq!(kind, EditKind::Value);
        assert_eq!(key.as_deref(), Some("greeting"));
        assert_eq!(input, "hi there");
        assert!(!wb.is_editing());
    }

    #[test]
    fn new_entry_lifecycle_and_cancel() {
        let mut wb = sample();
        wb.begin_new_entry();
        assert!(wb.is_editing());
        assert_eq!(wb.editing().unwrap().kind, EditKind::NewEntry);
        wb.edit_editor_mut().unwrap().insert_str("name=Ada");
        // cancel discards without returning input
        wb.cancel_edit();
        assert!(!wb.is_editing());
        assert!(wb.commit_edit().is_none());
    }
}
