#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn append_creates_file_and_writes_entry() {
        let dir = std::env::temp_dir().join("statusline_debug_test");
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test-debug.log");
        let _ = fs::remove_file(&path); // clean slate

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
        // Should not panic
        let bad = std::path::PathBuf::from("/nonexistent/path/that/cannot/exist/debug.log");
        append_to_path(&bad, "{}"); // must not panic or return error
    }
}
