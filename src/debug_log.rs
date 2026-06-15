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
    let timestamp = format_timestamp();
    let _ = write!(file, "=== {timestamp} ===\n{raw}\n\n");
}

#[allow(dead_code)]
fn format_timestamp() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let s = secs % 60;
    let m = (secs / 60) % 60;
    let h = (secs / 3600) % 24;
    let days = secs / 86400;

    // Days since 1970-01-01 → Gregorian calendar
    let (year, month, day) = days_to_ymd(days);

    format!("{year:04}-{month:02}-{day:02}T{h:02}:{m:02}:{s:02}Z")
}

#[allow(dead_code)]
fn days_to_ymd(mut days: u64) -> (u64, u64, u64) {
    // Gregorian calendar computation from days since epoch
    let mut year = 1970u64;
    loop {
        let leap = is_leap(year);
        let days_in_year = if leap { 366 } else { 365 };
        if days < days_in_year {
            break;
        }
        days -= days_in_year;
        year += 1;
    }
    let leap = is_leap(year);
    let months = [31u64, if leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut month = 1u64;
    for &days_in_month in &months {
        if days < days_in_month {
            break;
        }
        days -= days_in_month;
        month += 1;
    }
    (year, month, days + 1)
}

#[allow(dead_code)]
#[allow(clippy::manual_is_multiple_of)]
fn is_leap(year: u64) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
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

    #[test]
    fn format_timestamp_looks_like_iso8601() {
        let ts = format_timestamp();
        // e.g. 2026-06-15T14:30:22Z
        assert_eq!(ts.len(), 20, "unexpected length: {ts}");
        assert!(ts.ends_with('Z'), "missing Z: {ts}");
        assert_eq!(&ts[4..5], "-", "missing year-month dash: {ts}");
        assert_eq!(&ts[7..8], "-", "missing month-day dash: {ts}");
        assert_eq!(&ts[10..11], "T", "missing T separator: {ts}");
    }
}
