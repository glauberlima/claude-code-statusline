use anyhow::{Context, Result};
use serde::Deserialize;

pub struct ClaudeInput {
    pub model_name: String,
    pub current_dir: String,
    pub context_size: u32,
    pub current_usage: u32,
    pub context_percent: u8,
    pub cost_usd: f64,
}

#[derive(Deserialize)]
struct RawInput {
    model: Option<RawModel>,
    workspace: Option<RawWorkspace>,
    context_window: Option<RawContextWindow>,
    cost: Option<RawCost>,
}

#[derive(Deserialize)]
struct RawModel {
    display_name: Option<String>,
    id: Option<String>,
}

#[derive(Deserialize)]
struct RawWorkspace {
    current_dir: Option<String>,
    project_dir: Option<String>,
}

#[derive(Deserialize)]
struct RawContextWindow {
    context_window_size: Option<u32>,
    remaining_percentage: Option<f64>,
    current_usage: Option<RawUsage>,
}

#[derive(Deserialize)]
struct RawUsage {
    input_tokens: Option<u32>,
    output_tokens: Option<u32>,
    cache_creation_input_tokens: Option<u32>,
    cache_read_input_tokens: Option<u32>,
}

#[derive(Deserialize)]
struct RawCost {
    total_cost_usd: Option<f64>,
}

pub fn parse(json: &str) -> Result<ClaudeInput> {
    let raw: RawInput = serde_json::from_str(json).context("invalid JSON from stdin")?;

    let model_name = raw
        .model
        .as_ref()
        .and_then(|m| m.display_name.clone().or_else(|| m.id.clone()))
        .unwrap_or_else(|| "unknown".to_string());

    let current_dir = raw
        .workspace
        .as_ref()
        .and_then(|w| w.current_dir.clone().or_else(|| w.project_dir.clone()))
        .unwrap_or_default();

    let current_dir = if validate_directory(&current_dir) {
        current_dir
    } else {
        String::new()
    };

    let cw = raw.context_window.as_ref();
    let context_size = cw.and_then(|c| c.context_window_size).unwrap_or(200_000);

    let usage = cw.and_then(|c| c.current_usage.as_ref());
    let current_usage = usage
        .map(|u| {
            u.input_tokens.unwrap_or(0)
                + u.output_tokens.unwrap_or(0)
                + u.cache_creation_input_tokens.unwrap_or(0)
                + u.cache_read_input_tokens.unwrap_or(0)
        })
        .unwrap_or(0);

    // Context window display: scale used% to the usable range.
    // Claude Code reserves ~16.5% of the total window as an autocompact buffer.
    // We subtract that buffer before scaling so the bar reaches 100% exactly when
    // autocompact triggers, not when the raw window is exhausted.
    //   usable_remaining = max(0, (remaining - 16.5) / 83.5 * 100)
    //   used = round(100 - usable_remaining)
    // Credit: normalization approach from gsd-statusline (https://github.com/open-gsd/gsd-core)
    const AUTO_COMPACT_BUFFER_PCT: f64 = 16.5;
    let context_percent = cw
        .and_then(|c| c.remaining_percentage)
        .map(|r| {
            let usable_remaining = ((r - AUTO_COMPACT_BUFFER_PCT) / (100.0 - AUTO_COMPACT_BUFFER_PCT) * 100.0).max(0.0);
            (100.0 - usable_remaining).round().clamp(0.0, 100.0) as u8
        })
        .unwrap_or(0);

    let cost_usd = raw
        .cost
        .as_ref()
        .and_then(|c| c.total_cost_usd)
        .unwrap_or(0.0);

    Ok(ClaudeInput {
        model_name,
        current_dir,
        context_size,
        current_usage,
        context_percent,
        cost_usd,
    })
}

/// Returns true if the path is safe to use with a git subprocess.
/// Rejects: `..` traversal, leading `~`, shell metacharacters (`$`, backtick, `;`), relative paths.
pub fn validate_directory(path: &str) -> bool {
    use std::path::{Component, Path};

    if path.is_empty() {
        return false;
    }
    if path.contains('\0') {
        return false;
    }
    if path.starts_with('~') {
        return false;
    }
    if path.contains('$') || path.contains('`') || path.contains(';') {
        return false;
    }
    let p = Path::new(path);
    if !p.is_absolute() {
        return false;
    }
    if p.components().any(|c| c == Component::ParentDir) {
        return false;
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    const MINIMAL: &str = r#"{
        "model": {"display_name": "Test Model"},
        "workspace": {"current_dir": "/tmp/test"},
        "context_window": {
            "context_window_size": 200000,
            "remaining_percentage": 72,
            "current_usage": {
                "input_tokens": 1000,
                "output_tokens": 500,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0
            }
        },
        "cost": {"total_cost_usd": 1.23}
    }"#;

    #[test]
    fn parses_model_display_name() {
        let r = parse(MINIMAL).unwrap();
        assert_eq!(r.model_name, "Test Model");
    }

    #[test]
    fn computes_context_percent() {
        let r = parse(MINIMAL).unwrap();
        assert_eq!(r.context_percent, 34); // normalized: (72 - 16.5) / 83.5 * 100 → 66.47% remaining → 34% used
    }

    #[test]
    fn computes_current_usage_sum() {
        let r = parse(MINIMAL).unwrap();
        assert_eq!(r.current_usage, 1500); // 1000 + 500
    }

    #[test]
    fn parses_cost() {
        let r = parse(MINIMAL).unwrap();
        assert!((r.cost_usd - 1.23).abs() < 0.001);
    }

    #[test]
    fn rejects_path_traversal() {
        assert!(!validate_directory("../etc/passwd"));
        assert!(!validate_directory("/home/user/../secret"));
        #[cfg(windows)]
        assert!(!validate_directory(r"C:\Users\foo\..\secret"));
    }

    #[test]
    fn rejects_tilde() {
        assert!(!validate_directory("~/projects"));
    }

    #[test]
    fn rejects_shell_metacharacters() {
        assert!(!validate_directory("/tmp/foo;rm -rf /"));
        assert!(!validate_directory("/tmp/$(evil)"));
        assert!(!validate_directory("/tmp/`evil`"));
    }

    #[test]
    fn accepts_absolute_path() {
        #[cfg(not(windows))]
        {
            assert!(validate_directory("/Users/glauberl/Dev/project"));
            assert!(validate_directory("/tmp/statusline-test"));
        }
        #[cfg(windows)]
        {
            assert!(validate_directory(r"C:\Users\foo\project"));
            assert!(validate_directory("C:/Users/foo/project"));
        }
    }

    #[test]
    fn falls_back_to_model_id_when_no_display_name() {
        let json = r#"{"model": {"id": "claude-sonnet-4-6"}}"#;
        let r = parse(json).unwrap();
        assert_eq!(r.model_name, "claude-sonnet-4-6");
    }

    #[test]
    #[cfg(not(windows))]
    fn falls_back_to_project_dir_when_no_current_dir() {
        let json = r#"{"workspace": {"project_dir": "/tmp/project"}}"#;
        let r = parse(json).unwrap();
        assert_eq!(r.current_dir, "/tmp/project");
    }

    #[test]
    #[cfg(windows)]
    fn falls_back_to_project_dir_when_no_current_dir() {
        let json = r#"{"workspace": {"project_dir": "C:\\Users\\foo\\project"}}"#;
        let r = parse(json).unwrap();
        assert_eq!(r.current_dir, r"C:\Users\foo\project");
    }

    #[test]
    fn invalid_dir_produces_empty_string() {
        let json = r#"{"workspace": {"current_dir": "../etc/passwd"}}"#;
        let r = parse(json).unwrap();
        assert!(r.current_dir.is_empty());
    }

    #[test]
    fn rejects_relative_path() {
        assert!(!validate_directory("foo"));
        assert!(!validate_directory("relative/path"));
    }
}
