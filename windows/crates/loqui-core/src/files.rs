//! Changing loqui's own files safely while other threads read and add to them:
//! the dictation thread saves history and reads settings while the windows
//! save settings and delete or prune history.
//!
//! - Every read-change-write of a file holds [`lock`], and so does every line
//!   added to history, so a rewrite never writes back a copy read before
//!   another change landed.
//! - A whole file is replaced through a temporary file beside it
//!   ([`replace`]), so a reader sees the old file or the new one, never an
//!   empty or half-written one.

use std::fs;
use std::io;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, MutexGuard};

static WRITES: Mutex<()> = Mutex::new(());
/// Each temporary file gets its own name, even from two threads at once.
static TEMPS: AtomicU64 = AtomicU64::new(0);

/// Held while one of loqui's files is changed.
pub(crate) fn lock() -> MutexGuard<'static, ()> {
    WRITES
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Write `text` as the whole of `path`, all at once.
pub(crate) fn replace(path: &Path, text: &str) -> io::Result<()> {
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)?;
    }
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy())
        .unwrap_or_default();
    let n = TEMPS.fetch_add(1, Ordering::Relaxed);
    let temp = path.with_file_name(format!("{name}.{}-{n}.tmp", std::process::id()));
    fs::write(&temp, text)?;
    fs::rename(&temp, path).inspect_err(|_| {
        let _ = fs::remove_file(&temp);
    })
}
