# Repository Utilities (toolkit.nu)

Use a `toolkit.nu` file at the repository root for development commands. This provides a unified interface via subcommands.

## Structure

```nushell
# toolkit.nu - repository development utilities
use module/commands.nu *
use module

export def main [] { }  # Help message or list subcommands

# Subcommands use 'main <name>' pattern
export def 'main test' [
    --json   # output results as JSON
    --update # accept changes: stage modified files
    --fail   # exit with non-zero code if any tests fail (for CI)
] {
    let unit = main test-unit --json=$json
    let integration = main test-integration --json=$json --update=$update
    # ... combine and report results
}

export def 'main test-unit' [--json] { ... }
export def 'main test-integration' [--json --update] { ... }
export def 'main release' [--major (-M) --minor (-m)] { ... }
```

## Common Subcommands

| Command | Purpose |
|---------|---------|
| `main test` | Run all tests (unit + integration) |
| `main test-unit` | Run unit tests with nutest |
| `main test-integration` | Run snapshot/integration tests |
| `main release` | Version bump, tag, and push |

## Test Result Format

Return consistent structures for machine processing:

```nushell
{type: 'unit' name: $row.test status: 'passed' file: null}
{type: 'integration' name: $name status: 'changed' file: $output_file}
```

Status values: `passed`, `failed`, `changed` (for snapshot tests)

## Test Output with `--json` Flag

```nushell
export def 'main test-unit' [--json] {
    let results = nutest run-tests --path tests/ --returns table --display nothing
    | each {|row|
        let status = if $row.result == 'PASS' { 'passed' } else { 'failed' }
        {type: 'unit' name: $row.test status: $status file: null}
    }

    if not $json { $results | each {|r| print-test-result $r } }
    if $json { $results | to json --raw } else { $results }
}
```

## Conditional Module Availability

Check if optional module is available before using it:

```nushell
def update-dotnu-embeds [] {
    scope modules
    | where name == 'dotnu'
    | is-empty
    | if $in { return }

    dotnu embeds-update tests/dotnu-test.nu
}
```

## Const for Module Path Construction

Use `const` with `path join` for cross-platform module imports:

```nushell
# Cross-platform path to internal module
const numdinternals = ([numd commands.nu] | path join)
use $numdinternals [ build-modified-path compute-change-stats ]
```

## Commit Messages

Use Conventional commit format:

```
refactor: simplify closures using $in instead of named parameters
feat: add --ignore-git-check flag and error on uncommitted changes
fix: preserve existing $env.numd fields in load-config
```

| Type | Use for |
|------|---------|
| `feat:` | New features |
| `fix:` | Bug fixes |
| `refactor:` | Code changes without behavior change |
| `test:` | Test changes |
| `docs:` | Documentation only |
| `chore:` | Maintenance tasks |
