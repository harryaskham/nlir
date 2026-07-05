//! A pure, terminal-independent line editor for the interactive nlir REPL
//! (bd-ae1730). The ratatui reader in `main.rs` decodes key presses into calls
//! on this state machine and renders `buffer_string()` + `cursor()`; keeping all
//! editing logic here (no terminal handle) makes every shortcut — arrow-key
//! motion, `Ctrl-A`/`Ctrl-E`, word motions, kill/yank-less deletes, and Up/Down
//! history recall — unit-testable without a TTY.
//!
//! The buffer is a `Vec<char>` and the cursor is a **char index** in
//! `0..=buffer.len()`, so motion and deletion stay correct across the multi-byte
//! sigils nlir shorthand is built from (`~ @ ^ … ×`), where byte indexing would
//! split a codepoint.

/// A REPL line editor: edit buffer + cursor + submission history.
#[derive(Debug, Default, Clone)]
pub struct LineEditor {
    buffer: Vec<char>,
    /// Cursor position as a char index in `0..=buffer.len()`.
    cursor: usize,
    /// Submitted lines, oldest first, for Up/Down recall.
    history: Vec<String>,
    /// Index into `history` while browsing; `None` == editing the live buffer.
    history_pos: Option<usize>,
    /// The live buffer stashed when history browsing starts, restored on Down
    /// past the newest entry.
    stash: Option<Vec<char>>,
}

impl LineEditor {
    /// A fresh editor with an empty buffer and no history.
    pub fn new() -> Self {
        Self::default()
    }

    /// The current edit buffer as a `String`.
    pub fn buffer_string(&self) -> String {
        self.buffer.iter().collect()
    }

    /// Cursor position as a char index in `0..=len`.
    pub fn cursor(&self) -> usize {
        self.cursor
    }

    /// Whether the buffer is empty (used for the `Ctrl-D` == EOF guard).
    pub fn is_empty(&self) -> bool {
        self.buffer.is_empty()
    }

    /// Seed the recall history (e.g. from a persisted session) without touching
    /// the live buffer. Empty / duplicate-of-last lines are skipped.
    pub fn push_history(&mut self, line: impl Into<String>) {
        let line = line.into();
        if line.trim().is_empty() {
            return;
        }
        if self.history.last().map(String::as_str) == Some(line.as_str()) {
            return;
        }
        self.history.push(line);
    }

    /// Insert a char at the cursor and advance past it.
    pub fn insert_char(&mut self, c: char) {
        self.buffer.insert(self.cursor, c);
        self.cursor += 1;
    }

    /// Insert each char of `s` at the cursor (e.g. prefilling the context-edit
    /// box with a key's current value, or a bracketed paste).
    pub fn insert_str(&mut self, s: &str) {
        for c in s.chars() {
            self.insert_char(c);
        }
    }

    /// Delete the char before the cursor (Backspace).
    pub fn backspace(&mut self) {
        if self.cursor > 0 {
            self.cursor -= 1;
            self.buffer.remove(self.cursor);
        }
    }

    /// Delete the char under the cursor (Delete / `Ctrl-D` on a non-empty line).
    pub fn delete(&mut self) {
        if self.cursor < self.buffer.len() {
            self.buffer.remove(self.cursor);
        }
    }

    /// Move the cursor one char left (Left arrow).
    pub fn left(&mut self) {
        self.cursor = self.cursor.saturating_sub(1);
    }

    /// Move the cursor one char right (Right arrow).
    pub fn right(&mut self) {
        if self.cursor < self.buffer.len() {
            self.cursor += 1;
        }
    }

    /// Jump to the start of the line (`Ctrl-A` / Home).
    pub fn home(&mut self) {
        self.cursor = 0;
    }

    /// Jump to the end of the line (`Ctrl-E` / End).
    pub fn end(&mut self) {
        self.cursor = self.buffer.len();
    }

    /// Delete from the cursor to the end of the line (`Ctrl-K`).
    pub fn kill_to_end(&mut self) {
        self.buffer.truncate(self.cursor);
    }

    /// Delete from the start of the line to the cursor (`Ctrl-U`).
    pub fn kill_to_start(&mut self) {
        self.buffer.drain(0..self.cursor);
        self.cursor = 0;
    }

    /// Move left to the start of the previous word (`Ctrl-Left` / `Alt-B`).
    /// Words are runs of non-whitespace; leading whitespace is skipped first.
    pub fn word_left(&mut self) {
        let mut i = self.cursor;
        while i > 0 && self.buffer[i - 1].is_whitespace() {
            i -= 1;
        }
        while i > 0 && !self.buffer[i - 1].is_whitespace() {
            i -= 1;
        }
        self.cursor = i;
    }

    /// Move right to the end of the next word (`Ctrl-Right` / `Alt-F`).
    pub fn word_right(&mut self) {
        let len = self.buffer.len();
        let mut i = self.cursor;
        while i < len && self.buffer[i].is_whitespace() {
            i += 1;
        }
        while i < len && !self.buffer[i].is_whitespace() {
            i += 1;
        }
        self.cursor = i;
    }

    /// Delete the word before the cursor (`Ctrl-W`): trailing whitespace plus the
    /// preceding run of non-whitespace.
    pub fn delete_word_before(&mut self) {
        let start = {
            let mut i = self.cursor;
            while i > 0 && self.buffer[i - 1].is_whitespace() {
                i -= 1;
            }
            while i > 0 && !self.buffer[i - 1].is_whitespace() {
                i -= 1;
            }
            i
        };
        self.buffer.drain(start..self.cursor);
        self.cursor = start;
    }

    /// Discard the current line without recording history (`Ctrl-C`).
    pub fn discard(&mut self) {
        self.buffer.clear();
        self.cursor = 0;
        self.history_pos = None;
        self.stash = None;
    }

    /// Commit the current buffer as a submission: push it to history (unless
    /// blank or a duplicate of the last entry), reset for the next line, and
    /// return the submitted text.
    pub fn submit(&mut self) -> String {
        let line: String = self.buffer.iter().collect();
        self.push_history(line.clone());
        self.buffer.clear();
        self.cursor = 0;
        self.history_pos = None;
        self.stash = None;
        line
    }

    /// Recall the previous (older) history entry (Up arrow). Stashes the live
    /// buffer on the first step so Down can restore it.
    pub fn history_prev(&mut self) {
        if self.history.is_empty() {
            return;
        }
        let next = match self.history_pos {
            None => {
                self.stash = Some(std::mem::take(&mut self.buffer));
                self.history.len() - 1
            }
            Some(0) => 0,
            Some(pos) => pos - 1,
        };
        self.history_pos = Some(next);
        self.buffer = self.history[next].chars().collect();
        self.cursor = self.buffer.len();
    }

    /// Move toward newer history (Down arrow); stepping past the newest entry
    /// restores the stashed live buffer.
    pub fn history_next(&mut self) {
        let Some(pos) = self.history_pos else {
            return;
        };
        if pos + 1 < self.history.len() {
            self.history_pos = Some(pos + 1);
            self.buffer = self.history[pos + 1].chars().collect();
            self.cursor = self.buffer.len();
        } else {
            self.history_pos = None;
            self.buffer = self.stash.take().unwrap_or_default();
            self.cursor = self.buffer.len();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ed_with(s: &str) -> LineEditor {
        let mut e = LineEditor::new();
        e.insert_str(s);
        e
    }

    #[test]
    fn insert_advances_cursor_and_builds_buffer() {
        let e = ed_with("abc");
        assert_eq!(e.buffer_string(), "abc");
        assert_eq!(e.cursor(), 3);
    }

    #[test]
    fn insert_at_cursor_midline() {
        let mut e = ed_with("ac");
        e.left(); // between a and c
        e.insert_char('b');
        assert_eq!(e.buffer_string(), "abc");
        assert_eq!(e.cursor(), 2);
    }

    #[test]
    fn left_right_clamp_at_bounds() {
        let mut e = ed_with("ab");
        e.right(); // already at end
        assert_eq!(e.cursor(), 2);
        e.left();
        e.left();
        e.left(); // clamp at 0
        assert_eq!(e.cursor(), 0);
    }

    #[test]
    fn backspace_and_delete() {
        let mut e = ed_with("abc");
        e.backspace(); // "ab"
        assert_eq!(e.buffer_string(), "ab");
        assert_eq!(e.cursor(), 2);
        e.home();
        e.delete(); // remove 'a' under cursor -> "b"
        assert_eq!(e.buffer_string(), "b");
        assert_eq!(e.cursor(), 0);
        // backspace at start is a no-op
        e.backspace();
        assert_eq!(e.buffer_string(), "b");
    }

    #[test]
    fn home_end_ctrl_a_ctrl_e() {
        let mut e = ed_with("hello");
        e.home();
        assert_eq!(e.cursor(), 0);
        e.end();
        assert_eq!(e.cursor(), 5);
    }

    #[test]
    fn kill_to_end_and_start() {
        let mut e = ed_with("hello world");
        // cursor after "hello" (index 5)
        e.home();
        for _ in 0..5 {
            e.right();
        }
        e.kill_to_end();
        assert_eq!(e.buffer_string(), "hello");
        assert_eq!(e.cursor(), 5);

        let mut e = ed_with("hello world");
        e.home();
        for _ in 0..6 {
            e.right();
        }
        e.kill_to_start(); // drop "hello "
        assert_eq!(e.buffer_string(), "world");
        assert_eq!(e.cursor(), 0);
    }

    #[test]
    fn word_motion_left_right() {
        let mut e = ed_with("foo bar baz");
        e.word_left(); // from end into start of "baz"
        assert_eq!(e.cursor(), 8);
        e.word_left();
        assert_eq!(e.cursor(), 4); // start of "bar"
        e.word_right();
        assert_eq!(e.cursor(), 7); // end of "bar"
        e.word_right();
        assert_eq!(e.cursor(), 11); // end of "baz"
    }

    #[test]
    fn delete_word_before_ctrl_w() {
        let mut e = ed_with("foo bar ");
        e.delete_word_before(); // drop trailing ws + "bar"
        assert_eq!(e.buffer_string(), "foo ");
        assert_eq!(e.cursor(), 4);
        e.delete_word_before();
        assert_eq!(e.buffer_string(), "");
        assert_eq!(e.cursor(), 0);
    }

    #[test]
    fn multibyte_sigils_cursor_is_char_indexed() {
        // nlir shorthand uses multi-byte glyphs; motion/deletion must be by char.
        let mut e = ed_with("~@×");
        assert_eq!(e.cursor(), 3);
        e.backspace(); // remove '×'
        assert_eq!(e.buffer_string(), "~@");
        assert_eq!(e.cursor(), 2);
        e.home();
        e.delete(); // remove '~'
        assert_eq!(e.buffer_string(), "@");
    }

    #[test]
    fn submit_pushes_history_and_resets() {
        let mut e = ed_with("first");
        assert_eq!(e.submit(), "first");
        assert!(e.is_empty());
        assert_eq!(e.cursor(), 0);
        // blank submissions are not recorded
        assert_eq!(e.submit(), "");
        // consecutive duplicates collapse
        e.insert_str("dup");
        e.submit();
        e.insert_str("dup");
        e.submit();
        e.history_prev();
        assert_eq!(e.buffer_string(), "dup");
        e.history_prev();
        assert_eq!(e.buffer_string(), "first");
    }

    #[test]
    fn history_prev_next_recall_and_restore_stash() {
        let mut e = LineEditor::new();
        e.insert_str("one");
        e.submit();
        e.insert_str("two");
        e.submit();
        // start typing a live line, then browse up
        e.insert_str("liv");
        e.history_prev();
        assert_eq!(e.buffer_string(), "two");
        e.history_prev();
        assert_eq!(e.buffer_string(), "one");
        e.history_prev(); // clamp at oldest
        assert_eq!(e.buffer_string(), "one");
        e.history_next();
        assert_eq!(e.buffer_string(), "two");
        e.history_next(); // past newest -> restore stashed live line
        assert_eq!(e.buffer_string(), "liv");
        // Down with no active browse is a no-op
        e.history_next();
        assert_eq!(e.buffer_string(), "liv");
    }

    #[test]
    fn history_next_without_browsing_is_noop() {
        let mut e = ed_with("abc");
        e.history_next();
        assert_eq!(e.buffer_string(), "abc");
        assert_eq!(e.cursor(), 3);
    }

    #[test]
    fn discard_clears_without_history() {
        let mut e = ed_with("scratch");
        e.discard();
        assert!(e.is_empty());
        // nothing to recall
        e.history_prev();
        assert!(e.is_empty());
    }

    #[test]
    fn recalled_line_is_editable_then_submits_as_new_entry() {
        let mut e = LineEditor::new();
        e.insert_str("alpha");
        e.submit();
        e.history_prev();
        assert_eq!(e.buffer_string(), "alpha");
        e.insert_str("X"); // edit the recalled line
        assert_eq!(e.buffer_string(), "alphaX");
        assert_eq!(e.submit(), "alphaX");
    }
}
