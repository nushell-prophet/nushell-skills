# Pipeline Patterns

Detailed examples for Nushell pipeline composition.

## Leading Pipe Operator

Place `|` at the start of continuation lines, left-aligned with `let`:

```nushell
# Preferred
let row_type = $file_lines
| each {
    str trim --right
    | if $in =~ '^```' { } else { 'text' }
}
| scan --noinit 'text' {|curr prev| ... }

# Avoid
let row_type = $file_lines | each {
    str trim --right | if $in =~ '^```' { } else { 'text' }
} | scan --noinit 'text' {|curr prev| ... }
```

## Omit Redundant `$in |` Prefix

When a command body starts with a pipeline command (`each`, `where`, `select`, etc.), omit the `$in |` prefix—the input flows automatically:

```nushell
# Preferred: pipeline command receives input directly
export def extract-agents []: table -> table {
    where name? == "Task"
    | each { ... }
}

# Avoid: redundant $in
export def extract-agents []: table -> table {
    $in
    | where name? == "Task"
    | each { ... }
}
```

Note: `$in` IS needed when you must capture the value in a variable:

```nushell
# $in needed: value used in multiple places
export def extract-timestamps []: table -> record {
    let $input = $in

    let $ts = $input | get timestamp?

    {
        first: ($ts | first)
        last: ($ts | last)
    }
}
```

## Conditional Pass-Through with Empty `{ }`

Use empty `{ }` for the branch that passes through unchanged:

```nushell
# Pass through on false condition
| if $nu.os-info.family == windows {
    str replace --all (char crlf) "\n"
} else { }

# Pass through on true condition
| if $echo { } else {
    save -f $file
}

# Multiple chained conditions
| if 'no-output' in $fence_options { return $in } else { }
| if 'separate-block' in $fence_options { generate-separate-block-fence } else { }
| if (can-append-print $in) {
    generate-inline-output-pipeline
    | generate-print-statement
} else { }
```

## `scan` for Stateful Transformations

Use `scan` from the standard library (`std/iter`) for sequences with state:

```nushell
use std/iter scan

# State machine for tracking fence context
| scan 'text' {|curr_fence prev_fence|
    match $curr_fence {
        'text' => { if $prev_fence == 'closing-fence' { 'text' } else { $prev_fence } }
        '```' => { if $prev_fence == 'text' { '```' } else { 'closing-fence' } }
        _ => { $curr_fence }
    }
}

# Use --noinit (-n) to exclude the initial value from results
| scan --noinit 'text' {|curr prev| ... }
```

## `window` for Adjacent Elements

```nushell
| window --remainder 2
| scan 0 {|window index|
    if $window.0 == $window.1? { $index } else { $index + 1 }
}
```

## Combine Consecutive `each` Closures

When consecutive `each` calls perform operations that can be piped, combine them:

```nushell
# Preferred: single each with piped operations
| each { extract-text-content | str length }

# Avoid: separate each calls
| each { extract-text-content }
| each { str length }
```

## Closure Parameters: `$in` vs Named

Use `$in` for simple single-operation closures. Use short-named parameters (`|b|`, `|r|`, `|x|`) when the closure has multiple operations or references the value more than twice:

```nushell
# Multiple operations - use named parameter
| each {|b|
    if $b.block_index in $result_indices {
        let result = $results | where block_index == $b.block_index
        $b | update line { $result.line | lines }
    }
}

# Variable used >2 times - use named parameter
| each {|r| {start: $r.start, end: $r.end, len: ($r.end - $r.start)} }

# Simple single operation - $in is fine
| each { $in + 1 }
| each { $"prefix: ($in)" }

# Field extraction - use get, not each
| get line
| get field --optional
```

## Data-First Filtering

Define all data upfront, then filter. Prefer `where` over `each {if} | compact`:

```nushell
# Preferred: data-first, filter with where
[
    [--env-config $nu.env-path]
    [--config $nu.config-path]
    [--plugin-config $nu.plugin-path]
]
| where {|i| $i.1 | path exists }
| flatten

# Avoid: spread operator with conditionals
[
    ...(if ($nu.env-path | path exists) { [--env-config $nu.env-path] } else { [] })
    ...(if ($nu.config-path | path exists) { [--config $nu.config-path] } else { [] })
]
```

## Pipeline Append vs Spread

```nushell
# Preferred: start empty, append conditionally
[]
| if $cond1 { append [a b] } else { }
| if $cond2 { append [c d] } else { }

# Or: data-first with filtering
[[a b] [c d]]
| where { some-condition $in }
| flatten
```

## Building Tables with `wrap` and `merge`

```nushell
$file_lines | wrap line
| merge ($row_type | wrap row_type)
| merge ($block_index | wrap block_index)
| group-by block_index --to-table
| insert row_type { $in.items.row_type.0 }
| update items { get line }
| rename block_index line row_type
```

---

## Command Examples

### `match` for Type/Pattern Dispatch

```nushell
export def classify-block-action [
    $row_type: string
]: nothing -> string {
    match $row_type {
        'text' => { 'print-as-it-is' }
        '```output-numd' => { 'delete' }

        $i if ($i =~ '^```nu(shell)?(\s|$)') => {
            if $i =~ 'no-run' { 'print-as-it-is' } else { 'execute' }
        }

        _ => { 'print-as-it-is' }
    }
}
```

### `items` for Record Iteration

```nushell
$record
| items {|k v|
    $v
    | str replace -r '^\s*(\S)' '  $1'
    | str join (char nl)
    | $"($k):\n($in)"
}
```

### Safe Navigation with `?`

```nushell
$env.numd?.table-width? | default 120
$env.numd?.prepend-code?
```

### `in` for Membership Testing

```nushell
# Preferred
| where name? in ["Edit" "Write"]

# Avoid
| where { ($in.name? == "Edit") or ($in.name? == "Write") }
```

### `get --optional` for Field Extraction

Both forms produce the same result (list with nulls for missing fields), but `get` is more concise:

```nushell
# Preferred: get treats list-of-records as table
| get content --optional      # → [null, "result", null]

# Equivalent but verbose
| each { $in.content? }       # → [null, "result", null]

# For nested fields
| get input.file_path --optional

# Avoid: each + compact loses position information
| each { $in.input?.file_path? }
| compact
```

Note: `--optional` makes all path segments optional at once:
```nushell
get a.b.c --optional    # same as a?.b?.c?
get a.b?.c              # only b is optional
```

### `where` Row Conditions vs Closures

For simple conditions on lists, use row condition syntax (`$it`) instead of closures:

```nushell
# Preferred: row condition with $it
| where $it =~ $UUID_PATTERN
| where $it > 0

# Avoid: closure form for simple conditions
| where { $in =~ $UUID_PATTERN }
| where { $in > 0 }

# Closure IS needed when piping or multiple operations
| where {|i| $i.1 | path exists }
| where { $in | str starts-with "test" }
```

---

## Code Structure Examples

### Type Signatures

Always include input/output type signatures:

```nushell
export def clean-markdown []: string -> string {
    ...
}

export def parse-markdown-to-blocks []: string -> table<block_index: int, row_type: string, line: list<string>, action: string> {
    ...
}

# Multiple return types (no commas)
export def run [
    file: path
]: [nothing -> string nothing -> nothing nothing -> record] {
    ...
}
```

### @example Attributes (nutest)

Document commands with executable examples using [nutest](https://github.com/vyadh/nutest) attributes:

```nushell
@example "generate marker for block 3" {
    code-block-marker 3
} --result "#code-block-marker-open-3"
export def code-block-marker [
    index?: int
    --end
]: nothing -> string {
    ...
}
```

### Semantic Action Labels

Use meaningful labels instead of pattern matching throughout:

```nushell
# Preferred: semantic labels
| where action == 'execute'
| where action != 'delete'

# Avoid: repeated regex matching
| where row_type =~ '^```nu(shell)?(\s|$)'
```

### Module Exports for Testing

**Key pattern:** Nushell has no private/public distinction within a file. Use a two-file pattern:

1. **commands.nu** — export ALL commands (public + helpers) for testability
2. **mod.nu** — re-export only the public API

```nushell
# commands.nu - export EVERYTHING (enables unit testing of helpers)
export def my-command [] { ... }
export def helper-function [] { ... }  # internal helper, still exported
export def another-helper [] { ... }   # also exported

# mod.nu - control public API (what users see)
export use commands.nu [ my-command ]  # only my-command is public
```

Tests can then import everything:

```nushell
# tests/test_commands.nu
use ../module/commands.nu *  # access ALL commands including helpers
```

**When asked "should helpers be private/renamed?"** — the answer is:
- Keep them exported (for testing)
- Keep their current names (consistency within the module)
- The public API is controlled by mod.nu, not by removing exports

### Const for Static Data

```nushell
const fence_options = [
    [short long description];

    [O no-output "execute code without outputting results"]
    [N no-run "do not execute code in block"]
    [t try "execute block inside `try {}` for error handling"]
]

export def list-fence-options []: nothing -> table {
    $fence_options | select long short description
}
```

### Variable Naming

Use concise names for local variables with small scope; be more descriptive for parameters and exports:

```nushell
# Concise when scope is small and context is clear
| rename s f
| into int s f
let len = $longest_last_span_start - $last_span_end

# More descriptive for exports/parameters
export def process-blocks [block_index: int] { ... }
```

### Helper Extraction

Keep logic inline unless it's reused or the command becomes too long:

```nushell
# Inline when used once
| if (check-print-append $in) {
    create-indented-output
    | generate-print-statement
} else { }

# Extract when reused or complex
def apply-output-formatting []: string -> string { ... }
```

### Comments

Prefer comments that explain "why", not "what". **Never remove existing comments**:

```nushell
# Good: explain non-obvious decisions
# I set variables here to prevent collecting $in var
let expanded_format = "\n```\n\nOutput:\n\n```\n"
```
