pub const RED: &str = "\x1b[0;31m";
pub const GREEN: &str = "\x1b[0;32m";
pub const BLUE: &str = "\x1b[0;34m";
pub const MAGENTA: &str = "\x1b[0;35m";
pub const CYAN: &str = "\x1b[0;36m";
pub const ORANGE: &str = "\x1b[0;33m";
pub const GRAY: &str = "\x1b[0;90m";
pub const NC: &str = "\x1b[0m";

pub const BAR_FILLED: &str = "█";
pub const BAR_EMPTY: &str = "░";
pub const BAR_WIDTH: usize = 15;

// 256-color rainbow palette indices (matches bash WAVE_COLORS)
pub const WAVE_COLORS: &[u8] = &[196, 208, 220, 226, 118, 46, 48, 51, 33, 21, 93, 201];

// 256-color gradient: green → yellow → orange → red (positional, left=low usage, right=high)
pub const GRADIENT_COLORS: &[u8] = &[46, 82, 118, 154, 190, 226, 220, 214, 208, 202, 196];

pub fn separator() -> String {
    format!(" {GRAY}|{NC} ")
}

/// Join non-empty parts with the separator.
pub fn assemble(parts: &[String]) -> String {
    let sep = separator();
    let joined: String = parts
        .iter()
        .filter(|p| !p.is_empty())
        .cloned()
        .collect::<Vec<_>>()
        .join(&sep);
    format!("{joined}\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn assemble_joins_with_separator() {
        let parts = vec!["A".to_string(), "B".to_string(), "C".to_string()];
        let out = assemble(&parts);
        assert!(out.contains("A"));
        assert!(out.contains("B"));
        assert!(out.contains("C"));
    }

    #[test]
    fn assemble_skips_empty_parts() {
        let parts = vec!["A".to_string(), String::new(), "C".to_string()];
        let out = assemble(&parts);
        assert_eq!(out.matches("A").count(), 1);
        assert_eq!(out.matches("C").count(), 1);
        // 2 non-empty parts → exactly 1 separator; without filtering there would be 2
        assert_eq!(out.matches(GRAY).count(), 1);
        assert!(out.ends_with('\n'));
    }
}
