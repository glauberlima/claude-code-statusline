use std::io::Write;
use std::process::{Command, Stdio};

fn run_statusline(json: &str) -> String {
    let bin = env!("CARGO_BIN_EXE_statusline");
    let mut child = Command::new(bin)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("failed to spawn statusline binary");

    child
        .stdin
        .as_mut()
        .expect("stdin not piped")
        .write_all(json.as_bytes())
        .expect("failed to write stdin");

    let out = child.wait_with_output().expect("failed to wait for output");
    String::from_utf8_lossy(&out.stdout).into_owned()
}

#[test]
fn full_pipeline_minimal_fixture() {
    let json = include_str!("fixtures/test-input.json");
    let out = run_statusline(json);
    assert!(out.contains("Test Model"), "missing model name in: {out}");
    assert!(
        out.contains('█') || out.contains('░'),
        "missing progress bar in: {out}"
    );
}

#[test]
fn full_pipeline_real_fixture() {
    let json = include_str!("fixtures/claude-input-real.json");
    let out = run_statusline(json);
    assert!(out.contains("Sonnet 4.6"), "missing model in: {out}");
    assert!(
        out.contains('█') || out.contains('░'),
        "missing progress bar in: {out}"
    );
}

#[test]
fn output_ends_with_newline() {
    let json = include_str!("fixtures/test-input.json");
    let out = run_statusline(json);
    assert!(out.ends_with('\n'), "output must end with newline");
}

#[test]
fn contains_directory_icon() {
    let json = include_str!("fixtures/test-input.json");
    let out = run_statusline(json);
    assert!(out.contains("📁"), "missing dir icon in: {out}");
}
