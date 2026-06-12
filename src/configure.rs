use anyhow::Context;
use serde_json::json;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn run(settings_path: &str, command_path: &str) -> anyhow::Result<()> {
    let path = std::path::Path::new(settings_path);

    let (content, file_existed) = if path.exists() {
        (
            std::fs::read_to_string(path)
                .with_context(|| format!("statusline: cannot read settings file: {settings_path}"))?,
            true,
        )
    } else {
        (String::from("{}"), false)
    };

    let mut root: serde_json::Value = serde_json::from_str(&content).with_context(|| {
        format!("statusline: settings.json contains invalid JSON: {settings_path}")
    })?;

    let obj = root
        .as_object_mut()
        .ok_or_else(|| anyhow::anyhow!("statusline: settings.json root must be a JSON object"))?;

    if file_existed {
        let ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0);
        let backup = format!("{settings_path}.backup.{ms}");
        std::fs::copy(path, &backup)
            .with_context(|| format!("statusline: failed to backup settings.json: {backup}"))?;
        eprintln!("statusline: backed up settings to {backup}");
    }

    obj.insert(
        "statusLine".to_string(),
        json!({
            "type": "command",
            "command": command_path,
            "padding": 0
        }),
    );

    let serialized = serde_json::to_string_pretty(&root)
        .context("statusline: failed to serialize settings.json")?
        + "\n";

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("statusline: cannot create directory: {}", parent.display()))?;
    }

    let pid = std::process::id();
    let tmp_path = format!("{settings_path}.tmp.{pid}");
    std::fs::write(&tmp_path, &serialized)
        .with_context(|| format!("statusline: failed to write temp file: {tmp_path}"))?;
    std::fs::rename(&tmp_path, path).with_context(|| {
        let _ = std::fs::remove_file(&tmp_path);
        format!("statusline: failed to write settings.json: {settings_path}")
    })?;

    eprintln!("statusline: configured statusLine in {settings_path}");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn tmp_path(tag: u32) -> std::path::PathBuf {
        std::env::temp_dir().join(format!(
            "statusline-cfg-test-{}-{tag}",
            std::process::id()
        ))
    }

    #[test]
    fn creates_settings_json_when_missing() {
        let p = tmp_path(line!());
        let _ = fs::remove_file(&p);
        run(p.to_str().unwrap(), "~/.claude/statusline").unwrap();
        let v: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(&p).unwrap()).unwrap();
        assert_eq!(v["statusLine"]["command"], "~/.claude/statusline");
        fs::remove_file(&p).ok();
    }

    #[test]
    fn merges_preserving_other_keys() {
        let p = tmp_path(line!());
        fs::write(&p, r#"{"other":"value","nested":{"a":1}}"#).unwrap();
        run(p.to_str().unwrap(), "~/.claude/statusline").unwrap();
        let v: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(&p).unwrap()).unwrap();
        assert_eq!(v["other"], "value");
        assert_eq!(v["nested"]["a"], 1);
        assert_eq!(v["statusLine"]["type"], "command");
        fs::remove_file(&p).ok();
    }

    #[test]
    fn overwrites_existing_statusline_key() {
        let p = tmp_path(line!());
        fs::write(&p, r#"{"statusLine":{"type":"old","command":"old","padding":99}}"#).unwrap();
        run(p.to_str().unwrap(), "~/.claude/statusline").unwrap();
        let v: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(&p).unwrap()).unwrap();
        assert_eq!(v["statusLine"]["command"], "~/.claude/statusline");
        assert_eq!(v["statusLine"]["padding"], 0);
        fs::remove_file(&p).ok();
    }

    #[test]
    fn creates_backup_of_existing_file() {
        let p = tmp_path(line!());
        fs::write(&p, r#"{"x":1}"#).unwrap();
        run(p.to_str().unwrap(), "~/.claude/statusline").unwrap();
        let dir = p.parent().unwrap();
        let name = p.file_name().unwrap().to_str().unwrap();
        let backups: Vec<_> = fs::read_dir(dir)
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_str()
                    .unwrap_or("")
                    .starts_with(&format!("{name}.backup."))
            })
            .collect();
        assert!(!backups.is_empty(), "no backup file found");
        for b in backups {
            fs::remove_file(b.path()).ok();
        }
        fs::remove_file(&p).ok();
    }

    #[test]
    fn rejects_invalid_json() {
        let p = tmp_path(line!());
        fs::write(&p, "not json {{{{").unwrap();
        assert!(run(p.to_str().unwrap(), "~/.claude/statusline").is_err());
        fs::remove_file(&p).ok();
    }

    #[test]
    fn rejects_non_object_json() {
        let p = tmp_path(line!());
        fs::write(&p, "[1,2,3]").unwrap();
        assert!(run(p.to_str().unwrap(), "~/.claude/statusline").is_err());
        fs::remove_file(&p).ok();
    }

    #[test]
    fn output_is_valid_json_with_newline() {
        let p = tmp_path(line!());
        let _ = fs::remove_file(&p);
        run(p.to_str().unwrap(), "~/.claude/statusline").unwrap();
        let content = fs::read_to_string(&p).unwrap();
        assert!(content.ends_with('\n'), "output must end with newline");
        assert!(serde_json::from_str::<serde_json::Value>(&content).is_ok());
        fs::remove_file(&p).ok();
    }

    #[test]
    fn uses_provided_command_path_verbatim() {
        let p = tmp_path(line!());
        let _ = fs::remove_file(&p);
        run(p.to_str().unwrap(), "/custom/path/statusline").unwrap();
        let v: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(&p).unwrap()).unwrap();
        assert_eq!(v["statusLine"]["command"], "/custom/path/statusline");
        fs::remove_file(&p).ok();
    }
}
