use crate::config::{BarStyle, Config, ContextTier, get_messages};
use crate::git::{GitInfo, GitState};
use crate::input::ClaudeInput;
use crate::render::{
    BAR_EMPTY, BAR_FILLED, BAR_WIDTH, BLUE, CYAN, GRADIENT_COLORS, GRAY, GREEN, MAGENTA, NC,
    ORANGE, RED, WAVE_COLORS,
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
    let pct = (input.context_percent as f32 + config.usage_offset)
        .clamp(0.0, 100.0) as u8;
    let bar = build_usage_bar(pct, config.usage_bar_style, wave_time);
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

fn fill_plain(filled: usize, percent: u8) -> String {
    if filled == 0 {
        return String::new();
    }
    let tier = ContextTier::from_percent(percent);
    let color = match tier {
        ContextTier::VeryLow => GREEN,
        ContextTier::Low => CYAN,
        ContextTier::Medium | ContextTier::High => ORANGE,
        ContextTier::Critical => RED,
    };
    let mut s = color.to_string();
    for _ in 0..filled {
        s.push_str(BAR_FILLED);
    }
    s.push_str(NC);
    s
}

fn fill_rainbow(filled: usize, wave_time: u64) -> String {
    if filled == 0 {
        return String::new();
    }
    let phase = (wave_time as usize) % WAVE_COLORS.len();
    let mut s = String::new();
    for i in 0..filled {
        let idx = (i + phase) % WAVE_COLORS.len();
        s.push_str(&format!("\x1b[38;5;{}m{BAR_FILLED}", WAVE_COLORS[idx]));
    }
    s.push_str(NC);
    s
}

fn fill_gradient(filled: usize) -> String {
    if filled == 0 {
        return String::new();
    }
    let mut s = String::new();
    for i in 0..filled {
        let idx = if BAR_WIDTH > 1 {
            i * (GRADIENT_COLORS.len() - 1) / (BAR_WIDTH - 1)
        } else {
            0
        };
        s.push_str(&format!("\x1b[38;5;{}m{BAR_FILLED}", GRADIENT_COLORS[idx]));
    }
    s.push_str(NC);
    s
}

pub fn build_usage_bar(percent: u8, style: BarStyle, wave_time: u64) -> String {
    let pct = percent.clamp(0, 100) as usize;
    let filled = pct * BAR_WIDTH / 100;
    let empty = BAR_WIDTH - filled;

    let colored = match style {
        BarStyle::Plain => fill_plain(filled, percent),
        BarStyle::Rainbow => fill_rainbow(filled, wave_time),
        BarStyle::Gradient => fill_gradient(filled),
    };

    let mut bar = colored;
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
        let bar = build_usage_bar(0, BarStyle::Plain, 0);
        assert_eq!(bar.chars().filter(|&c| c == '░').count(), 15);
        assert!(!bar.contains('█'));
    }

    #[test]
    fn progress_bar_at_100() {
        let bar = build_usage_bar(100, BarStyle::Plain, 0);
        assert!(bar.contains('█'));
    }

    #[test]
    fn progress_bar_at_50_has_mixed_chars() {
        let bar = build_usage_bar(50, BarStyle::Plain, 0);
        assert!(bar.contains('█'));
        assert!(bar.contains('░'));
    }

    #[test]
    fn gradient_bar_empty() {
        let bar = build_usage_bar(0, BarStyle::Gradient, 0);
        assert!(!bar.contains('█'));
        assert_eq!(bar.chars().filter(|&c| c == '░').count(), 15);
        // no gradient color codes when empty
        assert!(!bar.contains("\x1b[38;5;"));
    }

    #[test]
    fn gradient_bar_full_starts_green_ends_red() {
        let bar = build_usage_bar(100, BarStyle::Gradient, 0);
        assert!(bar.contains('█'));
        // first color code must be GRADIENT_COLORS[0] = 46 (green)
        assert!(bar.contains("\x1b[38;5;46m"), "first char must be green (46)");
        // last filled color code must be GRADIENT_COLORS[10] = 196 (red)
        assert!(bar.contains("\x1b[38;5;196m"), "last char must be red (196)");
    }

    #[test]
    fn gradient_bar_half_no_red() {
        // 50% fill = 7 chars; index reaches GRADIENT_COLORS[4]=190 at most (halfway through palette)
        let bar = build_usage_bar(50, BarStyle::Gradient, 0);
        assert!(bar.contains('█'));
        assert!(bar.contains('░'));
        // 196 is the last red — should not appear at 50%
        assert!(!bar.contains("\x1b[38;5;196m"), "red (196) must not appear at 50%");
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
    fn context_offset_increases_displayed_percent() {
        let input = default_input(); // context_percent = 14
        let mut cfg = default_config();
        cfg.usage_offset = 10.0;
        let out = build_context(&input, &cfg, 0);
        // Should show 24%, not 14%
        assert!(out.contains("24%"), "expected 24% but got: {out}");
    }

    #[test]
    fn context_offset_clamped_at_100() {
        let mut input = default_input();
        input.context_percent = 95;
        let mut cfg = default_config();
        cfg.usage_offset = 20.0; // 95 + 20 = 115, clamped to 100
        let out = build_context(&input, &cfg, 0);
        assert!(out.contains("100%"), "expected 100% but got: {out}");
    }

    #[test]
    fn context_offset_negative_clamped_at_0() {
        let mut input = default_input();
        input.context_percent = 5;
        let mut cfg = default_config();
        cfg.usage_offset = -20.0; // 5 - 20 = -15, clamped to 0
        let out = build_context(&input, &cfg, 0);
        assert!(out.contains("0%"), "expected 0% but got: {out}");
    }

    #[test]
    fn context_offset_zero_leaves_unchanged() {
        let input = default_input(); // context_percent = 14
        let cfg = default_config(); // usage_offset defaults to 0.0
        let out = build_context(&input, &cfg, 0);
        assert!(out.contains("14%"), "zero offset must not change percent");
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
