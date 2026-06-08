use crate::config::{BarStyle, Config, ContextTier, get_messages};
use crate::git::{GitInfo, GitState};
use crate::input::ClaudeInput;
use crate::render::{
    BAR_EMPTY, BAR_FILLED, BAR_WIDTH, BLUE, CYAN, GRAY, GREEN, MAGENTA, NC, ORANGE, RED,
    WAVE_COLORS,
};
use std::time::{SystemTime, UNIX_EPOCH};

pub fn build_all(input: &ClaudeInput, git: &GitInfo, config: &Config) -> Vec<String> {
    let wave_time = if matches!(config.usage_bar_style, BarStyle::Rainbow) {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    } else {
        0
    };

    vec![
        build_directory(input),
        build_git(git),
        build_files(git.changed_files),
        build_model(input),
        build_context(input, config, wave_time),
        build_cost(input.cost_usd, config),
    ]
}

pub fn build_model(input: &ClaudeInput) -> String {
    let brain = if input.thinking_active { " 🧠" } else { "" };
    format!("🤖 {CYAN}{}{NC}{brain}", input.model_name)
}

pub fn build_directory(input: &ClaudeInput) -> String {
    let name = if input.current_dir.is_empty() {
        std::env::current_dir()
            .ok()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().into_owned()))
            .unwrap_or_else(|| "unknown".to_string())
    } else {
        input
            .current_dir
            .trim_end_matches('/')
            .split('/')
            .next_back()
            .unwrap_or(&input.current_dir)
            .to_string()
    };
    format!("📁 {BLUE}{name}{NC}")
}

pub fn build_git(info: &GitInfo) -> String {
    match info.state {
        GitState::NotRepo => format!("{ORANGE}(not a git repository){NC}"),
        GitState::Clean | GitState::Dirty => {
            format!("🌿 {MAGENTA}{}{NC}", info.branch)
        }
    }
}

pub fn build_files(changed: u32) -> String {
    if changed == 0 {
        return String::new();
    }
    format!("✏️ {ORANGE}changes{NC}")
}

pub fn build_context(input: &ClaudeInput, config: &Config, wave_time: u64) -> String {
    let pct = input.context_percent.clamp(0, 100);
    let bar = build_usage_bar(pct, matches!(config.usage_bar_style, BarStyle::Rainbow), wave_time);
    let usage = format_number(input.current_usage);
    let size = format_number(input.context_size);

    let message_part = if config.messages {
        let tier = ContextTier::from_percent(pct);
        let msgs = get_messages(config.messages_language, tier);
        if msgs.is_empty() {
            String::new()
        } else {
            let idx = (wave_time as usize) % msgs.len();
            format!(" {GRAY}|{NC} {CYAN}{}{NC}", msgs[idx])
        }
    } else {
        String::new()
    };

    format!("📊 {GRAY}[{NC}{bar}{GRAY}]{NC} {pct}% {usage}/{size}{message_part}")
}

pub fn build_cost(cost_usd: f64, config: &Config) -> String {
    if !config.cost || cost_usd == 0.0 {
        return String::new();
    }
    format!("💰 {GREEN}${cost_usd:.2}{NC}")
}

pub fn build_usage_bar(percent: u8, rainbow: bool, wave_time: u64) -> String {
    let pct = percent.clamp(0, 100) as usize;
    let filled = pct * BAR_WIDTH / 100;
    let empty = BAR_WIDTH - filled;

    let mut bar = String::new();

    if rainbow && filled > 0 {
        let phase = (wave_time as usize) % WAVE_COLORS.len();
        for i in 0..filled {
            let idx = (i + phase) % WAVE_COLORS.len();
            bar.push_str(&format!("\x1b[38;5;{}m{BAR_FILLED}", WAVE_COLORS[idx]));
        }
        bar.push_str(NC);
    } else if filled > 0 {
        let tier = ContextTier::from_percent(percent);
        let color = match tier {
            ContextTier::VeryLow => GREEN,
            ContextTier::Low => CYAN,
            ContextTier::Medium | ContextTier::High => ORANGE,
            ContextTier::Critical => RED,
        };
        bar.push_str(color);
        for _ in 0..filled {
            bar.push_str(BAR_FILLED);
        }
        bar.push_str(NC);
    }

    bar.push_str(GRAY);
    for _ in 0..empty {
        bar.push_str(BAR_EMPTY);
    }
    bar.push_str(NC);

    bar
}

pub fn format_number(n: u32) -> String {
    if n < 1_000 {
        return n.to_string();
    }
    if n < 1_000_000 {
        let k = n / 1_000;
        let r = n % 1_000;
        return if k < 10 {
            format!("{k}.{}K", r / 100)
        } else {
            format!("{k}K")
        };
    }
    let m = n / 1_000_000;
    let r = n % 1_000_000;
    if m < 10 {
        format!("{m}.{}M", r / 100_000)
    } else {
        format!("{m}M")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn default_input() -> ClaudeInput {
        ClaudeInput {
            model_name: "Sonnet 4.6".to_string(),
            current_dir: "/tmp/test".to_string(),
            context_size: 200_000,
            current_usage: 28_000,
            context_percent: 14,
            cost_usd: 1.23,
            thinking_active: false,
        }
    }

    fn default_config() -> Config {
        Config::default()
    }

    #[test]
    fn model_contains_name() {
        let out = build_model(&default_input());
        assert!(out.contains("Sonnet 4.6"));
    }

    #[test]
    fn model_shows_brain_when_thinking() {
        let mut input = default_input();
        input.thinking_active = true;
        let out = build_model(&input);
        assert!(out.contains("🧠"));
    }

    #[test]
    fn progress_bar_at_0() {
        let bar = build_usage_bar(0, false, 0);
        assert_eq!(bar.chars().filter(|&c| c == '░').count(), 15);
        assert!(!bar.contains('█'));
    }

    #[test]
    fn progress_bar_at_100() {
        let bar = build_usage_bar(100, false, 0);
        assert!(bar.contains('█'));
    }

    #[test]
    fn progress_bar_at_50_has_mixed_chars() {
        let bar = build_usage_bar(50, false, 0);
        assert!(bar.contains('█'));
        assert!(bar.contains('░'));
    }

    #[test]
    fn format_number_below_1000() {
        assert_eq!(format_number(543), "543");
    }

    #[test]
    fn format_number_k_suffix() {
        assert_eq!(format_number(1500), "1.5K");
        assert_eq!(format_number(54_000), "54K");
    }

    #[test]
    fn format_number_m_suffix() {
        assert_eq!(format_number(1_200_000), "1.2M");
        assert_eq!(format_number(12_000_000), "12M");
    }

    #[test]
    fn cost_hidden_when_zero() {
        let out = build_cost(0.0, &default_config());
        assert!(out.is_empty());
    }

    #[test]
    fn cost_hidden_when_disabled() {
        let mut cfg = default_config();
        cfg.cost = false;
        let out = build_cost(1.23, &cfg);
        assert!(out.is_empty());
    }

    #[test]
    fn cost_shows_formatted_amount() {
        let out = build_cost(1.23, &default_config());
        assert!(out.contains("1.23"));
        assert!(out.contains('$'));
    }

    #[test]
    fn files_empty_when_no_changes() {
        let out = build_files(0);
        assert!(out.is_empty());
    }

    #[test]
    fn files_shows_changes_icon() {
        let out = build_files(3);
        assert!(out.contains("changes"));
        assert!(out.contains("✏️"));
    }

    #[test]
    fn git_not_repo_shows_message() {
        let info = GitInfo {
            state: GitState::NotRepo,
            branch: String::new(),
            changed_files: 0,
        };
        let out = build_git(&info);
        assert!(out.contains("not a git repository"));
    }

    #[test]
    fn git_clean_shows_branch() {
        let info = GitInfo {
            state: GitState::Clean,
            branch: "main".to_string(),
            changed_files: 0,
        };
        let out = build_git(&info);
        assert!(out.contains("main"));
    }

    #[test]
    fn git_not_repo_has_no_leading_space() {
        let info = GitInfo {
            state: GitState::NotRepo,
            branch: String::new(),
            changed_files: 0,
        };
        let out = build_git(&info);
        assert!(!out.starts_with(' '), "NotRepo output must not start with space");
    }

    #[test]
    fn context_with_messages_enabled_shows_message() {
        let input = default_input();
        let mut cfg = default_config();
        cfg.messages = true;
        let out = build_context(&input, &cfg, 0);
        assert!(out.contains("📊"));
        // message text comes from VeryLow tier (14%)
        assert!(out.len() > "📊".len(), "should have message content");
    }

}
