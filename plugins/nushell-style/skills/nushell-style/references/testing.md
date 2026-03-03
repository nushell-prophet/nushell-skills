# Testing Infrastructure

## Running Nushell from Bash (Agent Escaping)

**⚠ `nu -c` is broken for `!=` and `!~`** — the Bash tool escapes `!` → `\!` before the shell sees it. Both single and double quotes are affected. This is not a bash issue — it happens at the tool level.

```bash
# BROKEN: Bash tool turns != into \!=
nu -c 'where status != "done"'     # → \!= → parse error
nu -c "where name !~ 'test'"       # → \!~ → parse error

# SAFE: operators without ! work fine
nu -c 'where status == "done"'     # ✓
nu -c 'where name =~ "test"'       # ✓
nu -c '"x" not-in ["y"]'           # ✓
```

**Fix 1 — inline heredoc** (preferred for short snippets):

```bash
nu -c "$(cat << 'EOF'
if ($data | length) != 0 { print "has data" }
$data | where name !~ "skip"
EOF
)"
```

**Fix 2 — temp file** (preferred for longer code):

```bash
cat > /tmp/test.nu << 'EOF'
let data = [{a: 1}, {a: 2}]
if ($data | length) != 0 {
    print "has data"
}
$data | where a > 1 | to nuon
EOF
nu /tmp/test.nu
```

Both use quoted heredoc (`<< 'EOF'`) which bypasses the escaping entirely.

## Unit Tests with nutest

Use the [nutest](https://github.com/vyadh/nutest) framework for unit tests. Note: `@test`, `@before-each`, `@after-each`, and `@example` are nutest-specific attributes, not part of standard Nushell.

### Test File Structure

```nushell
# tests/test_commands.nu
use std/assert

# Import all custom commands (including internals) for testability
use ../module/commands.nu *

@test
def "command-name handles specific case" [] {
    let result = 'input' | command-name

    assert equal $result 'expected'
}

@test
def "command-name with edge case" [] {
    let result = '' | command-name

    assert equal ($result | length) 0
}
```

### Test Naming Convention

Use descriptive names with the command being tested:

```nushell
@test
def "extract-command-name handles export def" [] { ... }

@test
def "extract-command-name handles simple def" [] { ... }

@test
def "dependencies excludes calls inside attribute blocks" [] { ... }
```

### Setup and Teardown

Use `@before-each` and `@after-each` for test fixtures:

```nushell
@before-each
def setup [] {
    let temp = mktemp --directory
    { temp: $temp }
}

@after-each
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

@test
def "suite files with default glob" [] {
    let temp = $in.temp  # Access context from setup
    touch ($temp | path join "test_foo.nu")
    # ... test logic
}
```

### Running Tests

```nushell
# Via toolkit
nu toolkit.nu test
nu toolkit.nu test-unit

# Direct nutest invocation
use nutest
nutest run-tests --path tests/ --match-suites 'test_commands' --returns table
```

## Snapshot/Integration Tests

Snapshot tests run commands and save output to files committed to git. `git diff` reveals behavioral changes.

### Pattern

1. Define test as closure capturing the command to run
2. Save output with embedded source code as header
3. Use `git diff --quiet` to detect changes
4. Optionally `--update` to stage changed files

```nushell
export def 'main test-integration' [--json --update] {
    let results = [
        (run-snapshot-test 'dependencies' 'tests/output/deps.yaml' {
            glob tests/assets/*.nu | dependencies ...$in | to yaml
        })
        (run-snapshot-test 'embeds-remove' 'tests/output/clean.nu' {
            open tests/assets/dirty.nu | embeds-remove
        })
    ]

    if $update {
        $results | where status == 'changed' | each {|r|
            ^git add $r.file
            print $"(ansi green)Staged:(ansi reset) ($r.file)"
        }
    }

    if $json { $results | to json --raw } else { $results }
}
```

### Snapshot Test Helper

For integration tests that compare output against committed files:

```nushell
def run-snapshot-test [name: string output_file: string command_src: closure] {
    mkdir ($output_file | path dirname)

    # Embed source code as header comment for self-documentation
    let command_text = view source $command_src
    | lines | skip | drop | str trim
    | each { $'# ($in)' }
    | str join (char nl)

    try {
        $command_text + (char nl) + (do $command_src)
        | save -f $output_file

        let diff = do { ^git diff --quiet $output_file } | complete
        let status = if $diff.exit_code == 0 { 'passed' } else { 'changed' }
        {type: 'integration' name: $name status: $status file: $output_file}
    } catch {
        {type: 'integration' name: $name status: 'failed' file: $output_file}
    }
}
```

### Lightweight Integration Test Helper

For tests that don't need embedded source headers:

```nushell
def run-integration-test [name: string, command_src: closure] {
    try {
        do $command_src

        let diff = do { ^git diff --quiet $name } | complete
        let status = if $diff.exit_code == 0 { 'passed' } else { 'changed' }
        {type: 'integration' name: ($name | path basename) status: $status file: $name}
    } catch {
        {type: 'integration' name: ($name | path basename) status: 'failed' file: $name}
    }
}
```

### Parallel Integration Tests

Use `par-each --keep-order` for concurrent test execution with deterministic output:

```nushell
glob z_examples/*/*.md --exclude [*/*_with_no_output* */*_customized*]
| par-each --keep-order {|file|
    run-integration-test $file {
        numd run $file --eval (open -r config.nu)
    }
}
# Chain additional test variants
| append (run-integration-test 'variant_width20' {
    numd run $file --echo --eval '$env.numd.table-width = 20' | save -f $target
})
```

## Test Organization

```
repo/
├── toolkit.nu              # Development utilities
├── module/
│   ├── mod.nu              # Public API
│   └── commands.nu         # Implementation (export all for testing)
└── tests/
    ├── test_commands.nu    # Unit tests
    ├── assets/             # Test input files
    │   ├── example.nu
    │   └── edge-case.nu
    └── output/             # Snapshot outputs (committed to git)
        ├── deps.yaml
        └── clean.nu
```

## Assertion Patterns

```nushell
# Equality
assert equal $result 'expected'
assert equal ($result | length) 3

# Boolean conditions
assert ($result | str starts-with '# => ')
assert ($result =~ 'pattern')
assert ($result !~ 'unwanted')

# Negative assertions
assert ('item' not-in $list)
assert (($filtered | length) == 0)

# With custom message
assert (($errors | length) == 0) "should have no errors"
```

## Test Grouping with Comments

Group related tests with section comments:

```nushell
# =============================================================================
# Tests for extract-command-name
# =============================================================================

@test
def "extract-command-name handles export def" [] { ... }

@test
def "extract-command-name handles simple def" [] { ... }

# =============================================================================
# Tests for dependencies
# =============================================================================

@test
def "dependencies returns table with expected columns" [] { ... }
```

## Embedded Output Tests (dotnu embeds)

For interactive development and inline documentation, use dotnu's embeds system. Commands ending with `| print $in` become capture points where output is embedded as `# => ` comments.

### Capture Point Pattern

```nushell
# Script with capture points
ls | length | print $in
# => 42

['a' 'b'] | str join ', ' | print $in
# => a, b
```

### Workflow

```nushell
# 1. Setup capture environment
dotnu embeds-setup my-script.nu

# 2. Add capture point interactively (from REPL after running a command)
some-command | dotnu embed-add

# 3. Update all embedded outputs in a file
dotnu embeds-update my-script.nu

# 4. Remove all embedded outputs (clean script)
open my-script.nu | dotnu embeds-remove
```

### Use Cases

- **Self-documenting scripts**: Output embedded next to commands that produce it
- **Regression detection**: `git diff` shows when output changes
- **Interactive exploration**: Capture REPL experiments directly into scripts

## Test Coverage Analysis

Use dotnu's `dependencies` command to analyze which commands call which, then `filter-commands-with-no-tests` to find untested code.

### Basic Coverage Check

```nushell
# Find untested commands in a module
glob module/*.nu
| dependencies ...$in
| filter-commands-with-no-tests
| select caller filename_of_caller
```

### Coverage in toolkit.nu

```nushell
run-snapshot-test 'coverage' 'tests/output/coverage.yaml' {
    # Public API from mod.nu
    let public_api = open module/mod.nu
    | lines
    | where $it =~ '^\s+"'
    | each { str trim | str replace -r '^"([^"]+)".*' '$1' }

    # Find untested public commands
    let untested = glob module/*.nu tests/*.nu
    | dependencies ...$in
    | filter-commands-with-no-tests
    | where caller in $public_api
    | select caller

    {
        public_api_count: ($public_api | length)
        tested_count: (($public_api | length) - ($untested | length))
        untested: ($untested | get caller)
    }
    | to yaml
}
```

### How It Works

1. `dependencies` parses `.nu` files using AST to build caller→callee graph
2. `filter-commands-with-no-tests` removes commands that are:
   - Named with 'test' in the name
   - Defined in files matching `test*.nu`
   - Called by test commands (transitive coverage)

## CI/CD Integration

```yaml
# GitHub Actions example
- name: Run tests
  run: |
    nu -c "use nutest; nutest run-tests --fail --report {type: junit, path: results.xml}"

# GitLab CI example
test:
  script:
    - nu -c "use nutest; nutest run-tests --fail"
  artifacts:
    reports:
      junit: results.xml
```

## Common Pitfalls

### Missing @test annotation
```nushell
# ❌ Test not discovered
def "my test" [] { ... }

# ✅ Correct
@test
def "my test" [] { ... }
```

### Context comes from pipeline, not function call
```nushell
# ❌ Wrong
@test
def "test" [] {
    let ctx = setup
}

# ✅ Correct — context piped from @before-each
@test
def "test" [] {
    let ctx = $in
}
```

### Serial execution for shared state
```nushell
# Use @strategy for tests that must run sequentially
@strategy: serial
module test_database {
    @test
    def "test 1" [] { ... }

    @test
    def "test 2" [] { ... }
}
```
