# Testing

Quick guide for running statusline.sh tests.

## Quick Start

```bash
# Run unit tests
./tests/unit.sh

# Run integration tests
./tests/integration.sh

# Run shellcheck verification
./tests/shellcheck.sh

# Run all tests
./tests/unit.sh && ./tests/integration.sh && ./tests/shellcheck.sh
```

## Test Structure

- **unit.sh** - Component-level tests
  - Tests individual functions like `format_number()` and `get_context_message()`
  - Tests parsing and formatting logic
  - Fast execution (< 1 second)

- **integration.sh** - End-to-end tests
  - Tests complete statusline with various JSON inputs
  - Tests edge cases (null values, over-limit context, etc.)
  - Tests across different scenarios

- **shellcheck.sh** - Static analysis verification
  - Enforces zero-tolerance for shellcheck warnings
  - All 11 optional checks enabled (ultra-strict configuration)
  - Validates all scripts: statusline.sh, install.sh, and test scripts
  - Fast execution (< 1 second)

- **fixtures/** - Test data
  - `test-input.json` - Sample JSON for manual testing

## Manual Testing

```bash
# Test with sample input
cat tests/fixtures/test-input.json | ./statusline.sh

# Test with custom input
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/test"},"context_window":{"context_window_size":200000}}' | ./statusline.sh
```

## Prerequisites

Before running tests, ensure you have:
- Bash 3.2+
- jq (JSON processor)
- git 2.11+ (for git-related tests)
- shellcheck (for static analysis tests)

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

## For More Information

See [docs/TESTING.md](../docs/TESTING.md) for:
- Detailed testing guide
- Performance testing
- Platform-specific testing
- Adding new tests
- Continuous integration setup
