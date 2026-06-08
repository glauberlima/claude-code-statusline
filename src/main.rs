mod components;
mod config;
mod git;
mod input;
mod render;

use anyhow::Context;

fn main() -> anyhow::Result<()> {
    if std::env::args().any(|a| a == "--print-defaults") {
        print!("{}", config::print_defaults());
        return Ok(());
    }

    if std::env::args().any(|a| a == "--version") {
        println!("statusline {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }

    let raw = read_stdin()?;
    let input = input::parse(&raw)?;
    let config = config::load();
    let git_info = git::get_git_info(&input.current_dir);
    let parts = components::build_all(&input, &git_info, &config);
    print!("{}", render::assemble(&parts));
    Ok(())
}

fn read_stdin() -> anyhow::Result<String> {
    use std::io::Read;
    let mut buf = String::new();
    std::io::stdin()
        .read_to_string(&mut buf)
        .context("failed to read stdin")?;
    anyhow::ensure!(!buf.trim().is_empty(), "empty JSON input received");
    Ok(buf)
}
