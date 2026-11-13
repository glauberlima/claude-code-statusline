use anyhow::{Context, Result};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Deserializer};

pub struct ClaudeInput {
    pub model_name: String,
    pub current_dir: String,
    pub context_size: Option<u32>,
    pub current_usage: Option<u32>,
    pub context_percent: Option<u8>,
    pub cost_usd: f64,
    pub rate_5h: Option<RateWindow>,
    pub rate_7d: Option<RateWindow>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RateWindow {
    pub pct: u8,
    /// Unix epoch seconds when the window resets.
    pub resets_at: Option<u64>,
}

#[derive(Deserialize)]
struct RawInput {
    #[serde(default, deserialize_with = "lenient")]
    model: Option<RawModel>,
    #[serde(default, deserialize_with = "lenient")]
    workspace: Option<RawWorkspace>,
    #[serde(default, deserialize_with = "lenient")]
    context_window: Option<RawContextWindow>,
    #[serde(default, deserialize_with = "lenient")]
    cost: Option<RawCost>,
    #[serde(default, deserialize_with = "lenient")]
    rate_limits: Option<RawRateLimits>,
}

#[derive(Deserialize)]
struct RawModel {
    #[serde(default, deserialize_with = "lenient")]
    display_name: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    id: Option<String>,
}

#[derive(Deserialize)]
struct RawWorkspace {
    #[serde(default, deserialize_with = "lenient")]
    current_dir: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    project_dir: Option<String>,
}

#[derive(Deserialize)]
struct RawContextWindow {
    #[serde(default, deserialize_with = "lenient")]
    context_window_size: Option<u32>,
    #[serde(default, deserialize_with = "lenient")]
    current_usage: Option<RawUsage>,
}

#[derive(Deserialize)]
struct RawUsage {
    #[serde(default, deserialize_with = "lenient")]
    input_tokens: Option<u32>,
    #[serde(default, deserialize_with = "lenient")]
    output_tokens: Option<u32>,
    #[serde(default, deserialize_with = "lenient")]
    cache_creation_input_tokens: Option<u32>,
    #[serde(default, deserialize_with = "lenient")]
    cache_read_input_tokens: Option<u32>,
}

#[derive(Deserialize)]
struct RawRateLimits {
    #[serde(default, deserialize_with = "lenient")]
    five_hour: Option<RawRateWindow>,
    #[serde(default, deserialize_with = "lenient")]
    seven_day: Option<RawRateWindow>,
}

#[derive(Deserialize)]
struct RawRateWindow {
    #[serde(default, deserialize_with = "lenient")]
    used_percentage: Option<f64>,
    // f64, not u64, so a float epoch still converts instead of being dropped.
    #[serde(default, deserialize_with = "lenient")]
    resets_at: Option<f64>,
}

#[derive(Deserialize)]
struct RawCost {
    #[serde(default, deserialize_with = "lenient")]
    total_cost_usd: Option<f64>,
}

/// Field-level fallback: a value of the wrong type (float where an integer is
/// expected, string where a number is, …) becomes `None` instead of failing the
/// whole payload and blanking the statusline when Claude Code's schema drifts.
fn lenient<'de, D: Deserializer<'de>, T: DeserializeOwned>(d: D) -> Result<Option<T>, D::Error> {
    let value = serde_json::Value::deserialize(d)?;
    Ok(serde_json::from_value(value).ok())
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

    let current_usage = cw.and_then(|c| c.current_usage.as_ref()).map(|u| {
        u.input_tokens.unwrap_or(0)
            + u.output_tokens.unwrap_or(0)
            + u.cache_creation_input_tokens.unwrap_or(0)
            + u.cache_read_input_tokens.unwrap_or(0)
    });

    let context_size = cw.and_then(|c| c.context_window_size);

    // Claude Code reserves a fixed token buffer for output generation (capped at
    // 20,000 tokens) that isn't exposed in this JSON. We subtract that reserve
    // before scaling so the bar reflects usage against the *usable* window, not
    // the raw one. A fixed token amount (rather than a percentage) scales
    // correctly across context window sizes: the reserve doesn't grow just
    // because the window does.
    const OUTPUT_RESERVE_TOKENS: f64 = 20_000.0;
    let context_percent = match (current_usage, context_size) {
        (Some(usage), Some(size)) => {
            let usable = (size as f64 - OUTPUT_RESERVE_TOKENS).max(1.0);
            Some(((usage as f64 / usable) * 100.0).round().clamp(0.0, 100.0) as u8)
        }
        _ => None,
    };

    let cost_usd = raw
        .cost
        .as_ref()
        .and_then(|c| c.total_cost_usd)
        .unwrap_or(0.0);

    let rl = raw.rate_limits.as_ref();
    let rate_pct = |w: Option<&RawRateWindow>| {
        w.and_then(|w| {
            w.used_percentage.map(|p| RateWindow {
                pct: p.round().clamp(0.0, 100.0) as u8,
                resets_at: w.resets_at.filter(|t| *t > 0.0).map(|t| t as u64),
            })
        })
    };
    let rate_5h = rate_pct(rl.and_then(|r| r.five_hour.as_ref()));
    let rate_7d = rate_pct(rl.and_then(|r| r.seven_day.as_ref()));

    Ok(ClaudeInput {
        model_name,
        current_dir,
        context_size,
        current_usage,
        context_percent,
        cost_usd,
        rate_5h,
        rate_7d,
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
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    const MINIMAL: &str = r#"{
        "model": {"display_name": "Test Model"},
        "workspace": {"current_dir": "/tmp/test"},
        "context_window": {
            "context_window_size": 200000,
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
        assert_eq!(r.context_percent, Some(1)); // 1500 / (200000 - 20000) * 100 → 0.83% → 1% used
    }

    #[test]
    fn computes_current_usage_sum() {
        let r = parse(MINIMAL).unwrap();
        assert_eq!(r.current_usage, Some(1500)); // 1000 + 500
    }

    #[test]
    fn does_not_saturate_early_near_the_reserve_boundary() {
        let json = r#"{"context_window": {"context_window_size": 200000, "current_usage": {"input_tokens": 169000, "output_tokens": 0, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}}"#;
        let r = parse(json).unwrap();
        assert_eq!(r.context_percent, Some(94)); // 169000 / (200000 - 20000) * 100 → 93.9% → 94%, not 100%
    }

    #[test]
    fn clamps_to_100_once_usage_exceeds_the_usable_window() {
        let json = r#"{"context_window": {"context_window_size": 200000, "current_usage": {"input_tokens": 185000, "output_tokens": 0, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}}"#;
        let r = parse(json).unwrap();
        assert_eq!(r.context_percent, Some(100));
    }

    #[test]
    fn parses_rate_limits_rounded() {
        let json = r#"{"rate_limits": {"five_hour": {"used_percentage": 23.5, "resets_at": 1738425600}, "seven_day": {"used_percentage": 41.2, "resets_at": 1738857600}}}"#;
        let r = parse(json).unwrap();
        assert_eq!(
            r.rate_5h,
            Some(RateWindow {
                pct: 24,
                resets_at: Some(1738425600)
            })
        );
        assert_eq!(
            r.rate_7d,
            Some(RateWindow {
                pct: 41,
                resets_at: Some(1738857600)
            })
        );
    }

    #[test]
    fn rate_limits_tolerates_float_and_negative_resets_at() {
        let r = parse(r#"{"rate_limits": {"five_hour": {"used_percentage": 10, "resets_at": 1738425600.0}, "seven_day": {"used_percentage": 10, "resets_at": -5}}}"#).unwrap();
        assert_eq!(r.rate_5h.unwrap().resets_at, Some(1738425600));
        assert_eq!(r.rate_7d.unwrap().resets_at, None);
    }

    #[test]
    fn wrong_field_types_do_not_fail_parse() {
        let json = r#"{"model": {"display_name": 42}, "workspace": "oops", "context_window": {"context_window_size": 200000.5, "current_usage": {"input_tokens": "x"}}, "cost": {"total_cost_usd": "1"}}"#;
        let r = parse(json).unwrap();
        assert_eq!(r.model_name, "unknown");
        assert_eq!(r.context_size, None);
        assert_eq!(r.current_usage, Some(0));
        assert_eq!(r.cost_usd, 0.0);
    }

    #[test]
    fn rate_limits_absent_or_partial() {
        let r = parse(MINIMAL).unwrap();
        assert_eq!((r.rate_5h, r.rate_7d), (None, None));
        let r = parse(r#"{"rate_limits": {"five_hour": {"used_percentage": 150}}}"#).unwrap();
        assert_eq!(
            (r.rate_5h, r.rate_7d),
            (
                Some(RateWindow {
                    pct: 100,
                    resets_at: None
                }),
                None
            )
        );
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
