use std::process::Command;

#[derive(Debug)]
pub struct GitInfo {
    pub state: GitState,
    pub branch: String,
    pub changed_files: u32,
}

#[derive(Debug)]
pub enum GitState {
    NotRepo,
    Clean,
    Dirty,
}

impl Default for GitInfo {
    fn default() -> Self {
        Self {
            state: GitState::NotRepo,
            branch: String::new(),
            changed_files: 0,
        }
    }
}

/// Runs `git status --porcelain=v2 --branch --untracked-files=all`.
/// Always returns a valid GitInfo — never propagates errors.
pub fn get_git_info(dir: &str) -> GitInfo {
    if dir.is_empty() {
        return GitInfo::default();
    }

    let output = Command::new("git")
        .args([
            "status",
            "--porcelain=v2",
            "--branch",
            "--untracked-files=all",
        ])
        .current_dir(dir)
        .output();

    match output {
        Ok(o) if o.status.success() => {
            let text = String::from_utf8_lossy(&o.stdout);
            parse_porcelain_v2(&text)
        }
        _ => GitInfo::default(),
    }
}

pub(crate) fn parse_porcelain_v2(output: &str) -> GitInfo {
    if output.is_empty() {
        return GitInfo::default();
    }

    let mut branch = String::from("(detached HEAD)");
    let mut changed_files: u32 = 0;

    for line in output.lines() {
        if let Some(rest) = line.strip_prefix("# branch.head ") {
            if rest != "(detached)" {
                branch = rest.to_string();
            }
        } else if !line.starts_with('#') && !line.is_empty() {
            changed_files += 1;
        }
    }

    let state = if changed_files == 0 {
        GitState::Clean
    } else {
        GitState::Dirty
    };

    GitInfo {
        state,
        branch,
        changed_files,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_clean_repo() {
        let output = "# branch.oid abc123\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +0 -0\n";
        let info = parse_porcelain_v2(output);
        assert!(matches!(info.state, GitState::Clean));
        assert_eq!(info.branch, "main");
        assert_eq!(info.changed_files, 0);
    }

    #[test]
    fn parses_dirty_repo() {
        let output = "# branch.oid abc123\n# branch.head feature/x\n# branch.ab +2 -1\n1 .M N... 100644 100644 100644 aaa bbb src/lib.rs\n? untracked.txt\n";
        let info = parse_porcelain_v2(output);
        assert!(matches!(info.state, GitState::Dirty));
        assert_eq!(info.branch, "feature/x");
        assert_eq!(info.changed_files, 2);
    }

    #[test]
    fn detached_head_fallback() {
        let output = "# branch.oid abc123\n# branch.head (detached)\n# branch.ab +0 -0\n";
        let info = parse_porcelain_v2(output);
        assert_eq!(info.branch, "(detached HEAD)");
    }

    #[test]
    fn empty_output_returns_not_repo() {
        let info = parse_porcelain_v2("");
        assert!(matches!(info.state, GitState::NotRepo));
    }

    #[test]
    fn no_upstream() {
        // New repo with no upstream set has no branch.ab line
        let output = "# branch.oid abc123\n# branch.head main\n";
        let info = parse_porcelain_v2(output);
        assert!(matches!(info.state, GitState::Clean));
        assert_eq!(info.branch, "main");
    }
}
