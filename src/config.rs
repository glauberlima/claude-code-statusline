use serde::{Deserialize, Deserializer};

#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub messages: bool,
    #[serde(default = "default_true")]
    pub cost: bool,
    #[serde(default)]
    pub messages_language: Language,
    #[serde(default)]
    pub usage_bar_style: BarStyle,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            messages: false,
            cost: true,
            messages_language: Language::En,
            usage_bar_style: BarStyle::Plain,
        }
    }
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Copy, Default)]
pub enum BarStyle {
    #[default]
    Plain,
    Rainbow,
    Gradient,
}

impl<'de> Deserialize<'de> for BarStyle {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let s = String::deserialize(deserializer)?;
        match s.as_str() {
            "plain" => Ok(BarStyle::Plain),
            "rainbow" => Ok(BarStyle::Rainbow),
            "gradient" => Ok(BarStyle::Gradient),
            other => {
                eprintln!("statusline: unknown usage_bar_style \"{other}\", using \"plain\"");
                Ok(BarStyle::Plain)
            }
        }
    }
}

#[derive(Debug, Clone, Copy, Default)]
pub enum Language {
    #[default]
    En,
    Pt,
    Es,
}

impl<'de> Deserialize<'de> for Language {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let s = String::deserialize(deserializer)?;
        match s.as_str() {
            "en" => Ok(Language::En),
            "pt" => Ok(Language::Pt),
            "es" => Ok(Language::Es),
            other => {
                eprintln!("statusline: unknown messages_language \"{other}\", using \"en\"");
                Ok(Language::En)
            }
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum ContextTier {
    VeryLow,
    Low,
    Medium,
    High,
    Critical,
}

impl ContextTier {
    pub fn from_percent(pct: u8) -> Self {
        match pct {
            0..=20 => Self::VeryLow,
            21..=40 => Self::Low,
            41..=60 => Self::Medium,
            61..=80 => Self::High,
            _ => Self::Critical,
        }
    }
}

pub fn print_defaults() -> String {
    [
        "# statusline.toml — Claude Code Statusline configuration",
        "# Place alongside the statusline binary (~/.claude/statusline.toml)",
        "# All fields are optional. Shown values are defaults.",
        "#",
        "# cost = true               # show cost tracker [true|false]",
        "# messages = false          # show context messages [true|false]",
        "# messages_language = \"en\"  # message language [\"en\"|\"pt\"|\"es\"]",
        "# usage_bar_style = \"plain\" # usage bar style [\"plain\"|\"rainbow\"|\"gradient\"]",
    ]
    .join("\n")
        + "\n"
}

/// Load config from the directory containing the running binary.
/// Falls back to Config::default() on any error (missing file, parse error).
pub fn load() -> Config {
    match config_path().and_then(|p| std::fs::read_to_string(p).ok()) {
        Some(content) => toml::from_str(&content).unwrap_or_else(|e| {
            eprintln!("statusline: config parse error: {e}");
            Config::default()
        }),
        None => Config::default(),
    }
}

fn config_path() -> Option<std::path::PathBuf> {
    let exe = std::env::current_exe().ok()?;
    Some(exe.parent()?.join("statusline.toml"))
}

pub fn get_messages(lang: Language, tier: ContextTier) -> &'static [&'static str] {
    match (lang, tier) {
        (Language::En, ContextTier::VeryLow) => &[
            "just getting started",
            "barely touched it",
            "rookie numbers",
            "fresh as a daisy",
            "room for an elephant",
            "barely scratched the surface",
            "context? what context?",
            "zero stress mode",
            "could do this all day",
            "warming up the engines",
            "practically empty",
            "haven't even started yet",
            "smooth sailing ahead",
            "testing the waters",
            "this will go far",
            "still cold in here",
            "didn't break a sweat",
            "taking it slow",
            "plenty of runway left",
            "all systems nominal",
            "hardly made a dent",
            "got room to spare",
        ],
        (Language::En, ContextTier::Low) => &[
            "ate and left no crumbs",
            "light snacking",
            "taking it easy",
            "smooth operator",
            "just vibing",
            "cruising altitude reached",
            "sipping not gulping",
            "nice and steady",
            "feeling good about this",
            "like a walk in the park",
            "barely breaking a sweat",
            "coasting along nicely",
            "comfortable cruise",
            "nibbling around the edges",
            "hasn't warmed up yet",
            "too comfortable",
            "zen mode activated",
            "this rhythm is good",
            "feeling just right",
            "total tranquility",
            "not bad so far",
            "looking good",
        ],
        (Language::En, ContextTier::Medium) => &[
            "halfway there",
            "finding the groove",
            "building momentum",
            "picking up speed",
            "getting interesting",
            "this is where the fun begins",
            "entering the zone",
            "momentum is building",
            "getting warmer",
            "midpoint madness",
            "balanced as all things should be",
            "sweet spot territory",
            "perfectly balanced",
            "getting serious now",
            "halfway walked",
            "warming the turbines",
            "started to heat up",
            "catching rhythm",
            "starting to feel it",
            "can feel the weight now",
            "neither cold nor hot",
            "this is balanced",
            "gears are meshing",
        ],
        (Language::En, ContextTier::High) => &[
            "getting spicy",
            "filling up fast",
            "things are heating up",
            "now we're talking",
            "turning up the heat",
            "entering danger zone",
            "feeling the pressure",
            "this is getting real",
            "approaching the red zone",
            "intensity rising",
            "no more mr nice bot",
            "getting toasty in here",
            "full throttle mode",
            "heated up for good",
            "starting to get hot",
            "on fire",
            "cauldron is boiling",
            "starting to get heavy",
            "serious now",
            "sweating bullets",
            "things getting serious",
            "here we go",
            "warming the engine",
            "hold on tight",
        ],
        (Language::En, ContextTier::Critical) => &[
            "living dangerously",
            "pushing the limits",
            "houston we have a problem",
            "danger zone activated",
            "code like there's no tomorrow",
            "running on fumes",
            "this is fine",
            "spicy spicy spicy",
            "critical mass approaching",
            "yolo mode engaged",
            "no safety net here",
            "maximum overdrive",
            "somebody stop me",
            "pedal to the metal",
            "context window go brrrr",
            "on fire now",
            "at the limit already",
            "about to explode",
            "now we're screwed",
            "limit coming in hot",
            "someone help please",
            "going to explode",
            "all or nothing now",
            "hold my drink",
            "burning up already",
            "this will end badly",
            "limit is here",
            "can't take it anymore",
        ],

        (Language::Pt, ContextTier::VeryLow) => &[
            "de boa na lagoa",
            "nem esquentou",
            "calma Calabreso",
            "fichinha",
            "tranquilasso",
            "tá sussa",
            "cabe um busão aqui",
            "arranhei a superfície",
            "modo paz",
            "fresquinho",
            "nem comecei",
            "tá frio",
            "mal encostei",
            "tem espaço pra uns 10",
            "só testando",
            "tá clean",
            "zero preocupação",
            "moleza",
            "nem suar suei",
            "praticamente vazio",
            "isso vai longe",
            "beginners luck",
        ],
        (Language::Pt, ContextTier::Low) => &[
            "mamando",
            "stonks",
            "tá no papo",
            "foi no sapatinho",
            "show de bola",
            "tá liso",
            "papai chegou",
            "na moral",
            "só na vibe",
            "deslizando",
            "mamão com açúcar",
            "flow natural",
            "gg easy",
            "beleza pura",
            "confortável demais",
            "ritmo bom",
            "petiscando",
            "operador raiz",
            "firme e forte",
            "nada mal",
            "tá bonito",
            "altitude de cruzeiro",
        ],
        (Language::Pt, ContextTier::Medium) => &[
            "segundo tempo",
            "aí sim hein",
            "bora que bora",
            "pega visão",
            "subindo o nível",
            "engrenando",
            "na metade",
            "esquentando",
            "pegando ritmo",
            "ficando interessante",
            "aqui começa",
            "entrando na zona",
            "ganhando embalo",
            "acelerando",
            "balanceado",
            "metade andada",
            "nem frio nem quente",
            "começou a esquentar",
            "já sinto o peso",
            "embalo aumentando",
            "loucura do meio",
            "território ideal",
            "aquecendo turbinas",
        ],
        (Language::Pt, ContextTier::High) => &[
            "eita porra",
            "segura peão",
            "ficou sério",
            "caiu a ficha",
            "tá quente",
            "ih rapaz",
            "complicou",
            "agora vai",
            "eita lasca",
            "começou o show",
            "ferrou?",
            "acelera aí",
            "enchendo rápido",
            "esquentou de vez",
            "pegando fogo",
            "zona de perigo",
            "sentindo a pressão",
            "ficou real",
            "intensidade subindo",
            "suando frio",
            "lá vamos nós",
            "segura firme",
            "modo acelerador",
            "começando a ferver",
        ],
        (Language::Pt, ContextTier::Critical) => &[
            "socorro",
            "acabou",
            "ferrou",
            "deu ruim",
            "travou tudo",
            "crashou geral",
            "tá tudo certo",
            "isso é normal",
            "segue o jogo",
            "problema? que problema?",
            "confia",
            "tá tranquilo, tá favorável",
            "foi de base",
            "apaga e some",
            "já era",
            "deu PT",
            "perdemo",
            "RIP contexto",
            "deletou tudo",
            "no limite",
            "vivendo perigosamente",
            "sem rede",
            "alguém me segura",
            "pé na tábua",
            "vai explodir",
            "segura meu copo",
            "agora ferrou",
            "não aguento mais",
        ],

        (Language::Es, ContextTier::VeryLow) => &[
            "todo tranquilo",
            "sin apuros",
            "apenas arranqué",
            "fresco",
            "easy mode",
            "tutorial level",
            "zero stress",
            "ni empecé",
            "hay espacio de sobra",
            "esto está suave",
            "ni me preocupo",
            "modo relax",
            "recién comenzando",
            "pura calma",
            "cero drama",
            "súper light",
            "apenas tocando",
            "sin esfuerzo",
            "esto es fácil",
            "vamos tranqui",
            "todo bien",
            "nivel principiante",
        ],
        (Language::Es, ContextTier::Low) => &[
            "todo bajo control",
            "sin problemas",
            "vamos bien",
            "de lujo",
            "ez",
            "gg ez",
            "smooth",
            "ni me inmuto",
            "esto es pan comido",
            "fluyendo",
            "ritmo perfecto",
            "como mantequilla",
            "sin sudar",
            "controlado",
            "viento en popa",
            "me sobra",
            "deslizando",
            "cruising",
            "todo ok",
            "ni me esfuerzo",
            "pura vida",
            "nivel cómodo",
        ],
        (Language::Es, ContextTier::Medium) => &[
            "a medio camino",
            "segundo tiempo",
            "agarrando ritmo",
            "se pone bueno",
            "subiendo de nivel",
            "el juego se pone serio",
            "ahí vamos",
            "dale que dale",
            "empujando",
            "ni frío ni caliente",
            "aumentando ritmo",
            "calentando motores",
            "medio tanque",
            "equilibrado",
            "picking up speed",
            "engranando",
            "zona media",
            "sintiendo el peso",
            "más activo",
            "entrando en calor",
            "medio lleno",
            "esto avanza",
            "acelerando paso",
        ],
        (Language::Es, ContextTier::High) => &[
            "se puso feo",
            "se complica",
            "ojo",
            "caliente caliente",
            "esto se pone picante",
            "modo intenso",
            "lag real",
            "ahora sí",
            "sentí eso",
            "presión alta",
            "se prendió",
            "cosa seria",
            "subiendo la apuesta",
            "zona roja cerca",
            "se calienta",
            "intenso",
            "ya pesa",
            "full speed",
            "acelerado",
            "se siente",
            "cuesta arriba",
            "a tope",
            "nivel difícil",
            "empieza lo bueno",
        ],
        (Language::Es, ContextTier::Critical) => &[
            "auxilio",
            "se acabó",
            "estamos mal",
            "se cayó todo",
            "emergencia",
            "nos pasamos",
            "todo normal",
            "nada raro aquí",
            "confía",
            "esto está bien",
            "todo controlado",
            "sin problema",
            "F en el chat",
            "GG",
            "nos vemos",
            "crasheó bonito",
            "respawn incoming",
            "game over",
            "al límite",
            "sin frenos",
            "aguanta",
            "ya valió",
            "a full",
            "no aguanto",
            "zona peligrosa",
            "crítico",
            "máximo nivel",
            "explotando",
            "en el borde",
        ],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config_new_fields() {
        let c = Config::default();
        assert!(!c.messages);
        assert!(c.cost);
        assert!(matches!(c.usage_bar_style, BarStyle::Plain));
        assert!(matches!(c.messages_language, Language::En));
    }

    #[test]
    fn parse_toml_new_field_names() {
        let toml_str = r#"
messages = true
cost = false
messages_language = "pt"
usage_bar_style = "rainbow"
"#;
        let c: Config = toml::from_str(toml_str).unwrap();
        assert!(c.messages);
        assert!(!c.cost);
        assert!(matches!(c.messages_language, Language::Pt));
        assert!(matches!(c.usage_bar_style, BarStyle::Rainbow));
    }

    #[test]
    fn unknown_bar_style_falls_back_to_plain() {
        let toml_str = r#"usage_bar_style = "neon""#;
        let c: Config = toml::from_str(toml_str).unwrap();
        assert!(matches!(c.usage_bar_style, BarStyle::Plain));
    }

    #[test]
    fn unknown_language_falls_back_to_en() {
        let toml_str = r#"messages_language = "klingon""#;
        let c: Config = toml::from_str(toml_str).unwrap();
        assert!(matches!(c.messages_language, Language::En));
    }

    #[test]
    fn missing_fields_use_defaults() {
        let c: Config = toml::from_str("").unwrap();
        assert!(!c.messages);
        assert!(c.cost);
        assert!(matches!(c.usage_bar_style, BarStyle::Plain));
        assert!(matches!(c.messages_language, Language::En));
    }

    #[test]
    fn get_messages_returns_nonempty_slice() {
        for tier in [
            ContextTier::VeryLow,
            ContextTier::Low,
            ContextTier::Medium,
            ContextTier::High,
            ContextTier::Critical,
        ] {
            let msgs = get_messages(Language::En, tier);
            assert!(!msgs.is_empty(), "En tier {tier:?} has no messages");
            let msgs_pt = get_messages(Language::Pt, tier);
            assert!(!msgs_pt.is_empty(), "Pt tier {tier:?} has no messages");
            let msgs_es = get_messages(Language::Es, tier);
            assert!(!msgs_es.is_empty(), "Es tier {tier:?} has no messages");
        }
    }

    #[test]
    fn print_defaults_contains_all_fields() {
        let out = print_defaults();
        assert!(out.contains("cost = true"));
        assert!(out.contains("messages = false"));
        assert!(out.contains("messages_language = \"en\""));
        assert!(out.contains("usage_bar_style = \"plain\""));
        assert!(out.contains("[true|false]"));
        assert!(out.contains("[\"plain\"|\"rainbow\"|\"gradient\"]"));
    }

    #[test]
    fn tier_from_percent() {
        assert!(matches!(ContextTier::from_percent(0), ContextTier::VeryLow));
        assert!(matches!(
            ContextTier::from_percent(20),
            ContextTier::VeryLow
        ));
        assert!(matches!(ContextTier::from_percent(21), ContextTier::Low));
        assert!(matches!(ContextTier::from_percent(40), ContextTier::Low));
        assert!(matches!(ContextTier::from_percent(41), ContextTier::Medium));
        assert!(matches!(ContextTier::from_percent(60), ContextTier::Medium));
        assert!(matches!(ContextTier::from_percent(61), ContextTier::High));
        assert!(matches!(ContextTier::from_percent(80), ContextTier::High));
        assert!(matches!(
            ContextTier::from_percent(81),
            ContextTier::Critical
        ));
        assert!(matches!(
            ContextTier::from_percent(100),
            ContextTier::Critical
        ));
    }
}
