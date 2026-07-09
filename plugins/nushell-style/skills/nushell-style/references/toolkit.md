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
    --json   # force machine-readable JSON even on a terminal
    --pretty # force the human view even when piped
    --all    # human view: also list passing tests
    --update # accept changes: stage modified files
    --fail   # exit with non-zero code if any tests fail (for CI)
] {
    # collect-* are pure: they return rows and print nothing. Rendering happens once, here.
    let results = (collect-unit-results) | append (collect-integration-results --update=$update)
    if (machine-mode --json=$json --pretty=$pretty) {
        print ($results | to json --raw)
    } else {
        print-human $results --all=$all --update=$update
    }
    if $fail and ($results | where status == 'failed' | is-not-empty) { exit 1 }
}

export def 'main test-unit' [--json --pretty --all] { ... }
export def 'main test-integration' [--json --pretty --all --update] { ... }
export def 'main release' [--major --minor] { ... }
```

Split compute from rendering: `collect-*` functions return flat rows and print nothing, so every entry point (`test`, `test-unit`, `test-integration`) shares one renderer and one output-mode decision. See [Output Mode](#output-mode-auto-detect-failures-only) below.

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
{type: 'unit' name: $row.test status: 'passed' file: null message: null}
{type: 'integration' name: $name status: 'changed' file: $output_file message: null}
```

- Status values: `passed`, `failed`, `changed` (for snapshot tests).
- `status` is your own vocabulary — note it is **not** nutest's `result` column (`PASS`/`FAIL`). Document this next to the schema; guessing `result` is a common trip.
- `message` holds the assertion text on failure (`null` otherwise), so the machine channel tells a consumer not just *what* failed but *why*. For unit tests read it from nutest's `output.msg`; for integration tests from the caught error's `msg`.

## Output Mode: auto-detect, failures-only

The default consumer of a test runner is often an agent, not a human at a terminal. Design the output for both — without making either pass a flag in the common case.

**Detect the consumer with `is-terminal --stdout`, not `$nu.is-interactive`.** A terminal means a human is watching; a pipe or redirect means an agent or CI is capturing. `$nu.is-interactive` is the wrong signal — it reports REPL-ness, not human-ness: it is `false` for *any* `nu toolkit.nu ...` script run (whoever launched it) and `true` for an agent driving the Nushell MCP, so it detects the opposite of what you want.

```nushell
def machine-mode [--json --pretty]: nothing -> bool {
    if $pretty { return false }  # force the human view even when piped
    if $json { return true }     # force JSON even on a terminal
    not (is-terminal --stdout)   # else: pipe/redirect -> machine, terminal -> human
}

export def 'main test-unit' [
    --json   # force machine-readable JSON even on a terminal
    --pretty # force the human view even when piped
    --all    # human view: also list passing tests (default: failures only)
] {
    let flat = collect-unit-results  # pure: returns rows, prints nothing
    if (machine-mode --json=$json --pretty=$pretty) {
        $flat | to json --raw
    } else {
        print-human $flat --all=$all
    }
}
```

**The human view shows only non-passing tests, then a summary — and returns nothing.**

```nushell
def print-human [flat: table --all] {
    let to_show = if $all { $flat } else { $flat | where status != 'passed' }
    $to_show | each {|r| print-test-result $r }
    print-summary $flat  # "N passed, M failed" — always, even on all-pass
}
```

Two rules make this safe:

- **Return nothing in the human branch.** A returned table auto-renders through the implicit `table` command and truncates to 80 cols when stdout is not a wide terminal — cutting the `status` column, the one verdict that matters. The `print` lines are the human view; don't *also* return the table.
- **Flag polarity: failures are always loud; `--all` only *un-hides* passes.** Never a `--failures` flag that implies passes show by default — that could suppress a failure by accident. The summary always prints the pass count, so an all-pass run is one reassuring line, not silence.

**The JSON channel always carries every row.** Failures-only trimming is a human-view choice; a machine consumer filters itself. Serialize to JSON (not a bare Nushell table) because structured values don't survive crossing the `nu toolkit.nu ...` subprocess boundary. Route status notes (`Staged: …`, "nutest not found") to stderr with `print -e` so they never corrupt the JSON on stdout.

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
