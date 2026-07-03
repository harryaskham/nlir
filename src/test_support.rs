//! Shared `#[cfg(test)]` test helpers (bd-18297a).
//!
//! Dedups the throwaway-temp-file idiom that config/context unit tests each
//! re-implemented (`std::env::temp_dir().join(format!("…-{pid}-{nanos}"))` +
//! manual `fs::remove_*` cleanup), centralising the pid/nanos/seq naming and
//! guaranteeing cleanup even on panic via the [`TempPath`] RAII guard.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

/// Build a unique, not-yet-created path under the system temp dir:
/// `<tmp>/<tag>-<pid>-<nanos>-<seq>[.<ext>]`. A monotonic per-process sequence
/// guarantees uniqueness even for calls within the same nanosecond, replacing
/// the copy-pasted pid+nanos idiom. Pass an empty `ext` for a directory or an
/// extension-less path.
pub(crate) fn unique_temp_path(tag: &str, ext: &str) -> PathBuf {
    static SEQ: AtomicU64 = AtomicU64::new(0);
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let seq = SEQ.fetch_add(1, Ordering::Relaxed);
    let mut name = format!("{tag}-{}-{nanos}-{seq}", std::process::id());
    if !ext.is_empty() {
        name.push('.');
        name.push_str(ext);
    }
    std::env::temp_dir().join(name)
}

/// An RAII temp path removed on drop (best-effort, as a file *or* directory), so
/// tests never leak temp artefacts even when they panic mid-test.
pub(crate) struct TempPath {
    path: PathBuf,
}

impl TempPath {
    /// A unique temp path with the given `tag` and `ext` (empty `ext` for a
    /// directory / extension-less path). Not yet created on disk.
    pub(crate) fn new(tag: &str, ext: &str) -> Self {
        Self {
            path: unique_temp_path(tag, ext),
        }
    }

    /// The underlying path.
    pub(crate) fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for TempPath {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
        let _ = std::fs::remove_dir_all(&self.path);
    }
}
