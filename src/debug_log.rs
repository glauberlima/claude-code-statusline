use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[allow(dead_code)]
pub fn append(raw: &str) {
    let Some(home) = std::env::var_os("HOME") else {
        return;
    };
    let path = PathBuf::from(home).join(".claude").join("statusline-debug.log");
    append_to_path(&path, raw);
}

#[allow(dead_code)]
fn append_to_path(path: &Path, raw: &str) {
    let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) else {
        return;
    };
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let _ = write!(file, "=== {secs} ===\n{raw}\n\n");
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn append_creates_file_and_writes_entry() {
        let dir = std::env::temp_dir().join("statusline_debug_test");
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test-debug.log");
        let _ = fs::remove_file(&path);

        append_to_path(&path, "{}");

        let contents = fs::read_to_string(&path).unwrap();
        assert!(contents.contains("{}"), "raw json missing");
        assert!(contents.contains("==="), "separator missing");

        fs::remove_file(&path).unwrap();
    }

    #[test]
    fn append_accumulates_multiple_runs() {
        let dir = std::env::temp_dir().join("statusline_debug_test");
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test-debug-multi.log");
        let _ = fs::remove_file(&path);

        append_to_path(&path, "first");
        append_to_path(&path, "second");

        let contents = fs::read_to_string(&path).unwrap();
        assert!(contents.contains("first"), "first entry missing");
        assert!(contents.contains("second"), "second entry missing");

        fs::remove_file(&path).unwrap();
    }

    #[test]
    fn append_silent_on_bad_path() {
        let bad = std::path::PathBuf::from("/nonexistent/path/that/cannot/exist/debug.log");
        append_to_path(&bad, "{}");
    }
}
