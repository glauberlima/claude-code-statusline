# Changelog

## v1.1.0 — 2026-07-02

### Bug Fixes

- make install.ps1 work on Windows PowerShell 5.1 ([#38](https://github.com/glauberlima/claude-code-statusline/pull/38)) — [@AndreFornerr](https://github.com/AndreFornerr)
- prevent cliff exit code 1 from failing changelog step ([#47](https://github.com/glauberlima/claude-code-statusline/pull/47)) — [@glauberlima](https://github.com/glauberlima)
- pass --tag to cliff to fix null timestamp render error ([#48](https://github.com/glauberlima/claude-code-statusline/pull/48)) — [@glauberlima](https://github.com/glauberlima)
- use explicit range from last stable tag to HEAD for changelog ([#49](https://github.com/glauberlima/claude-code-statusline/pull/49)) — [@glauberlima](https://github.com/glauberlima)
- suppress ANSI color codes from cliff output with NO_COLOR=1 ([#50](https://github.com/glauberlima/claude-code-statusline/pull/50)) — [@glauberlima](https://github.com/glauberlima)
- patch install scripts in-place; fix asset upload filenames ([#54](https://github.com/glauberlima/claude-code-statusline/pull/54)) — [@glauberlima](https://github.com/glauberlima)
- replace VERSION env var with positional arg ([#60](https://github.com/glauberlima/claude-code-statusline/pull/60)) — [@glauberlima](https://github.com/glauberlima)
- capture version arg before arg-parsing loop consumes it ([#61](https://github.com/glauberlima/claude-code-statusline/pull/61)) — [@glauberlima](https://github.com/glauberlima)
- correct install script URLs to use raw.githubusercontent main ([#66](https://github.com/glauberlima/claude-code-statusline/pull/66)) — [@glauberlima](https://github.com/glauberlima)
- use Path API for directory validation and name extraction ([#68](https://github.com/glauberlima/claude-code-statusline/pull/68)) — [@glauberlima](https://github.com/glauberlima)
- remove param defaults for PS5.1 scriptblock compatibility ([#70](https://github.com/glauberlima/claude-code-statusline/pull/70)) — [@glauberlima](https://github.com/glauberlima)
- strip UTF-8 BOM from install.ps1 ([#71](https://github.com/glauberlima/claude-code-statusline/pull/71)) — [@glauberlima](https://github.com/glauberlima)
- remove .NET Core arch check incompatible with PS5.1 ([#74](https://github.com/glauberlima/claude-code-statusline/pull/74)) — [@glauberlima](https://github.com/glauberlima)
- remove WSL detection and replace jq with grep/tr ([#75](https://github.com/glauberlima/claude-code-statusline/pull/75)) — [@glauberlima](https://github.com/glauberlima)
- skull blinks, file count in changes, configure cleanup, docs ([#79](https://github.com/glauberlima/claude-code-statusline/pull/79)) — [@glauberlima](https://github.com/glauberlima)
- use explicit range from last stable tag for CHANGELOG ([#80](https://github.com/glauberlima/claude-code-statusline/pull/80)) — [@glauberlima](https://github.com/glauberlima)


### Documentation

- standardize named params across bash, ps1, readme, and ci ([#67](https://github.com/glauberlima/claude-code-statusline/pull/67)) — [@glauberlima](https://github.com/glauberlima)


### Features

- add gradient usage bar style ([#40](https://github.com/glauberlima/claude-code-statusline/pull/40)) — [@glauberlima](https://github.com/glauberlima)
- tag-pinned install scripts ([#51](https://github.com/glauberlima/claude-code-statusline/pull/51)) — [@glauberlima](https://github.com/glauberlima)
- serve install scripts as release assets ([#52](https://github.com/glauberlima/claude-code-statusline/pull/52)) — [@glauberlima](https://github.com/glauberlima)
- add dev-install.sh for fast local debug iteration ([#57](https://github.com/glauberlima/claude-code-statusline/pull/57)) — [@glauberlima](https://github.com/glauberlima)
- support VERSION env var to pin install to specific release ([#59](https://github.com/glauberlima/claude-code-statusline/pull/59)) — [@glauberlima](https://github.com/glauberlima)
- only apply usage_offset at or above 80% context usage ([#62](https://github.com/glauberlima/claude-code-statusline/pull/62)) — [@glauberlima](https://github.com/glauberlima)
- normalize context % against autocompact buffer ([#63](https://github.com/glauberlima/claude-code-statusline/pull/63)) — [@glauberlima](https://github.com/glauberlima)
- add gsd bar style with tier-based colors and critical blink ([#64](https://github.com/glauberlima/claude-code-statusline/pull/64)) — [@glauberlima](https://github.com/glauberlima)
- add pinned-version install block to release notes ([#65](https://github.com/glauberlima/claude-code-statusline/pull/65)) — [@glauberlima](https://github.com/glauberlima)
- VirusTotal binary scanning in release pipeline ([#72](https://github.com/glauberlima/claude-code-statusline/pull/72)) — [@glauberlima](https://github.com/glauberlima)
- fire/skull emojis for all bar styles with new thresholds ([#77](https://github.com/glauberlima/claude-code-statusline/pull/77)) — [@glauberlima](https://github.com/glauberlima)


### Performance

- skip early polls with 60s initial wait, reduce interval to 15s ([#73](https://github.com/glauberlima/claude-code-statusline/pull/73)) — [@glauberlima](https://github.com/glauberlima)

## v1.0.0 — 2026-06-11

### Breaking Changes

- rewrite statusline in Rust, replacing bash implementation ([#32](https://github.com/glauberlima/claude-code-statusline/pull/32)) — [@glauberlima](https://github.com/glauberlima)


### Bug Fixes

- create CHANGELOG.md if missing before git-cliff prepend ([#34](https://github.com/glauberlima/claude-code-statusline/pull/34)) — [@glauberlima](https://github.com/glauberlima)
- use GitHub App token for release pushes to bypass branch protection ([#35](https://github.com/glauberlima/claude-code-statusline/pull/35)) — [@glauberlima](https://github.com/glauberlima)


### Features

- add rainbow wave animation to progress bar ([#28](https://github.com/glauberlima/claude-code-statusline/pull/28)) — [@AurelianoBR](https://github.com/AurelianoBR)

