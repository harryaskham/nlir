//! nlir shared negative-index resolution.
//!
//! Both the evaluation stack (`$N`: `$0` bottom, `$-1` top) and message indexing
//! (`^N`: negatives from the end) resolve a possibly-negative index into a
//! bounded slice position with identical semantics. This is the single shared
//! implementation they both use (bd-410f4d).

/// Resolve a possibly-negative index into `[0, len)`: `index >= 0` counts from
/// the start, `index < 0` from the end (`-1` = last). Returns `None` when the
/// index falls outside the range.
#[must_use]
pub fn resolve_index(len: usize, index: i64) -> Option<usize> {
    let len_i = i64::try_from(len).ok()?;
    let resolved = if index < 0 { len_i + index } else { index };
    if resolved >= 0 && resolved < len_i {
        usize::try_from(resolved).ok()
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::resolve_index;

    #[test]
    fn resolve_index_handles_negatives_and_bounds() {
        assert_eq!(resolve_index(5, 0), Some(0));
        assert_eq!(resolve_index(5, 4), Some(4));
        assert_eq!(resolve_index(5, -1), Some(4)); // last
        assert_eq!(resolve_index(5, -5), Some(0)); // first from the end
        assert_eq!(resolve_index(5, 5), None); // past the end
        assert_eq!(resolve_index(5, -6), None); // before the start
        assert_eq!(resolve_index(0, 0), None); // empty
    }
}
