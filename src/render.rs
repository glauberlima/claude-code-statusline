pub const RED: &str = "\x1b[0;31m";
pub const GREEN: &str = "\x1b[0;32m";
pub const BLUE: &str = "\x1b[0;34m";
pub const MAGENTA: &str = "\x1b[0;35m";
pub const CYAN: &str = "\x1b[0;36m";
pub const ORANGE: &str = "\x1b[0;33m";
pub const ORANGE_256: &str = "\x1b[38;5;208m";
pub const GRAY: &str = "\x1b[0;90m";
pub const NC: &str = "\x1b[0m";

use crate::config::Theme;

/// The six semantic colors used by directory/git/files/model/cost/context components.
/// `Theme::Default` reuses the plain 16-color ANSI constants above; other themes
/// use truecolor (24-bit) escapes matching their official palettes.
pub struct Palette {
    pub blue: String,
    pub magenta: String,
    pub orange: String,
    pub cyan: String,
    pub green: String,
    pub red: String,
}

fn truecolor(r: u8, g: u8, b: u8) -> String {
    format!("\x1b[38;2;{r};{g};{b}m")
}

pub fn build_palette(theme: Theme) -> Palette {
    match theme {
        Theme::Default => Palette {
            blue: BLUE.to_string(),
            magenta: MAGENTA.to_string(),
            orange: ORANGE.to_string(),
            cyan: CYAN.to_string(),
            green: GREEN.to_string(),
            red: RED.to_string(),
        },
        Theme::Dracula => Palette {
            blue: truecolor(189, 147, 249),   // #bd93f9 purple
            magenta: truecolor(255, 121, 198), // #ff79c6 pink
            orange: truecolor(255, 184, 108),  // #ffb86c
            cyan: truecolor(139, 233, 253),    // #8be9fd
            green: truecolor(80, 250, 123),    // #50fa7b
            red: truecolor(255, 85, 85),       // #ff5555
        },
        Theme::TokyoNight => Palette {
            blue: truecolor(122, 162, 247),   // #7aa2f7
            magenta: truecolor(187, 154, 247), // #bb9af7
            orange: truecolor(224, 175, 104),  // #e0af68
            cyan: truecolor(125, 207, 255),    // #7dcfff
            green: truecolor(158, 206, 106),   // #9ece6a
            red: truecolor(247, 118, 142),     // #f7768e
        },
        Theme::OneDark => Palette {
            blue: truecolor(97, 175, 239),    // #61afef
            magenta: truecolor(198, 120, 221), // #c678dd
            orange: truecolor(209, 154, 102),  // #d19a66
            cyan: truecolor(86, 182, 194),     // #56b6c2
            green: truecolor(152, 195, 121),   // #98c379
            red: truecolor(224, 108, 117),     // #e06c75
        },
        Theme::SolarizedDark => Palette {
            blue: truecolor(38, 139, 210),    // #268bd2
            magenta: truecolor(211, 54, 130),  // #d33682
            orange: truecolor(203, 75, 22),    // #cb4b16
            cyan: truecolor(42, 161, 152),     // #2aa198
            green: truecolor(133, 153, 0),     // #859900
            red: truecolor(220, 50, 47),       // #dc322f
        },
        // P1 phosphor CRT green, with amber/red accents borrowed from period terminal alert colors
        Theme::Phosphor => Palette {
            blue: truecolor(51, 255, 51),      // #33ff33 bright phosphor green
            magenta: truecolor(255, 176, 0),   // #ffb000 amber (VT100/PLATO alert color)
            orange: truecolor(102, 255, 102),  // #66ff66 soft phosphor green
            cyan: truecolor(153, 255, 153),    // #99ff99 pale phosphor green
            green: truecolor(0, 204, 0),       // #00cc00 deep phosphor green
            red: truecolor(255, 51, 51),       // #ff3333 alarm red
        },
    }
}

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
    fn default_theme_palette_matches_ansi_constants() {
        let p = build_palette(Theme::Default);
        assert_eq!(p.blue, BLUE);
        assert_eq!(p.magenta, MAGENTA);
        assert_eq!(p.orange, ORANGE);
        assert_eq!(p.cyan, CYAN);
        assert_eq!(p.green, GREEN);
        assert_eq!(p.red, RED);
    }

    #[test]
    fn themed_palettes_use_truecolor_escapes() {
        for theme in [
            Theme::Dracula,
            Theme::TokyoNight,
            Theme::OneDark,
            Theme::SolarizedDark,
            Theme::Phosphor,
        ] {
            let p = build_palette(theme);
            for color in [&p.blue, &p.magenta, &p.orange, &p.cyan, &p.green, &p.red] {
                assert!(color.starts_with("\x1b[38;2;"), "{theme:?} color not truecolor: {color:?}");
            }
        }
    }

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
