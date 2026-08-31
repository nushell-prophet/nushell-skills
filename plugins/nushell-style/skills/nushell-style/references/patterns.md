# Pipeline Patterns

Detailed examples for Nushell pipeline composition.

## Leading Pipe Operator

Place `|` at the start of continuation lines, indented one level in from the line that opens the pipeline:

```nushell
# Preferred
let row_type = $file_lines
    | each {
        str trim --right
        | if $in =~ '^```' { } else { 'text' }
    }
    | scan --fold 'text' {|curr prev| ... }

# Avoid
let row_type = $file_lines | each {
    str trim --right | if $in =~ '^```' { } else { 'text' }
} | scan --fold 'text' {|curr prev| ... }
```

A pipeline on the right of `let x = …` is a nested expression, so its `|` sits one level in from the `let`.
A top-level pipeline is not nested, so its `|` stays at column 0:

```nushell
$file_lines | wrap line
| merge ($row_type | wrap row_type)
| group-by block_index --to-table
```

`topiary format --language nu` produces exactly this — the indent follows expression nesting, not the position of `let`.

## One Step Per Line

A new line per `|` is the default.
Two cases earn an exception:

**1. The stages read as one action.**
`| lines | str trim` is "get clean lines"; `| uniq --count | sort-by count --reverse` is "rank by frequency".
The reader takes each group in as a single move, so splitting it adds noise instead of removing it.

```nushell
# Preferred — one transformation per line, groups left intact
history --long
| where start_timestamp > ((date now) - 1wk)
| get command
| parse --regex '^(?<head>[\w-]+)' | get head
| uniq --count | sort-by count --reverse

# Avoid — five distinct steps hidden in one line
history --long | where start_timestamp > ((date now) - 1wk) | get command | uniq --count | sort-by count --reverse
```

**2. A short parenthesised subexpression.**
These are arguments to a command, not the shape of the pipeline, so they stay inline:

```nushell
| merge ($row_type | wrap row_type)
| where {|i| ($i.path | path expand | path exists) }
let cfg = (open $file | from json)
```

When a parenthesised subexpression grows past roughly one screen-width, give it its own `let` instead of breaking it across lines.

This is judgement, not a counter.
`git branch | lines | str trim` stays on one line because fetching and cleaning are one thought; a three-stage chain that filters, then rewrites, then writes does not.
The test is whether a reader must stop and follow each stage separately — not how many `|` the line contains.

## Other Operators Need Parentheses

`|` is the only operator that continues a line on its own.
A multi-line expression built with `++`, `+`, `and`, `or`, … does not parse: a leading operator is read as a command name (``Command `++` not found``), a trailing one leaves an `Incomplete math expression`.

```nushell
# Fails to parse
let parts = [--config $config_path]
    ++ (if $verbose { [--verbose] } else { [] })
    ++ [$script]

# Preferred: a pipeline, leading `|`
let parts = [--config $config_path]
    | append (if $verbose { [--verbose] } else { [] })
    | append $script

# Also correct: parens make the line break legal (leading or trailing operator both work there)
let parts = (
    [--config $config_path]
    ++ (if $verbose { [--verbose] } else { [] })
    ++ [$script]
)
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
    let input = $in

    let ts = $input | get timestamp?

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
    save --force $file
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
| scan --fold 'text' {|curr_fence prev_fence|
    match $curr_fence {
        'text' => { if $prev_fence == 'closing-fence' { 'text' } else { $prev_fence } }
        '```' => { if $prev_fence == 'text' { '```' } else { 'closing-fence' } }
        _ => { $curr_fence }
    }
}
```

Since 0.114 `scan` mirrors `reduce`: the seed goes in `--fold` (and stays in the output); without `--fold` the first element seeds.
The old positional init and `--noinit` are gone — for the `--noinit` behavior (seed excluded from output), follow `--fold $init` with `| skip 1`.

## `window` for Adjacent Elements

```nushell
| window --remainder 2
| scan --fold 0 {|window index|
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

## `each --keep-empty` Preserves Position

`each` drops the elements whose closure returned nothing, so the output is shorter than the input and the indices no longer line up.
`--keep-empty` keeps a `null` in place instead:

```nushell
[1 2 3] | each {|x| if $x mod 2 == 0 { $x } }                # => [2]
[1 2 3] | each --keep-empty {|x| if $x mod 2 == 0 { $x } }   # => [null, 2, null]
```

Reach for it whenever the result is going to be `zip`ped, `merge`d, or `wrap`ped back alongside the input — the same reason `get --optional` beats `each { $in.field? } | compact`.
It is also what makes "repeat a value n times" work when the value may be `null`:

```nushell
let item = null
1..3 | each { $item }                # => []
1..3 | each --keep-empty { $item }   # => [null, null, null]
```

## Composing Closures with `reduce --fold`

A list of transformations can be folded into a single closure, each one wrapping the last:

```nushell
let pipeline = [{str uppercase} {str reverse}]
    | reduce --fold ({|| $in }) {|step prev|
        {|| do $prev | do $step }
    }

"abc" | do $pipeline   # => CBA
```

The seed `{|| $in }` is the identity closure, so an empty list yields a pass-through.
Use this when the *set* of steps is data — driven by flags, a config record, or a table of columns.
For a fixed set of steps, just write the pipeline.

## Closure Parameters: `$in` vs Named

Use `$in` for simple single-operation closures.
Use short-named parameters (`|b|`, `|r|`, `|x|`) when the closure has multiple operations or references the value more than twice:

```nushell
# Multiple operations - use named parameter
| each {|b|
    if $b.block_index in $result_indices {
        let result = $results | where block_index == $b.block_index
        $b | update line { $result.line | lines }
    }
}

# Variable used >2 times - use named parameter
| each {|r| {start: $r.start end: $r.end len: ($r.end - $r.start)} }

# Simple single operation - $in is fine
| each { $in + 1 }
| each { $"prefix: ($in)" }

# Field extraction - use get, not each
| get line
| get field --optional
```

## Data-First Filtering

Define all data upfront, then filter.
Prefer `where` over `each {if} | compact`:

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

### Input-Type Dispatch with `peek | metadata access`

When a command has to behave differently depending on what type it was piped, don't collect the input to look at it.
`peek` stashes the first `n` elements in the pipeline metadata while the stream keeps flowing, and `metadata access` reads them:

```nushell
export def "into list" []: any -> list {
    peek | metadata access {|md|
        match $md.peek.type {
            "range" => { each {|| } }
            "list" => { }
            "record" => { transpose key value }
            _ => { [$in] }
        }
    }
}
```

`1..3` → `[1 2 3]`, `[1 2]` → `[1 2]`, `{a: 1}` → a two-column table, `"x"` → `["x"]`.

Prefer this over `let x = $in; match ($x | describe) { … }`, which collects the whole stream just to name its type.

**`peek` reports a coarser type than `describe`, and that decides most sites.**
`$md.peek.type` is the bare type name, so the distinctions `describe` draws inside the angle brackets are all gone (measured on 0.115.1):

```nushell
[[a b]; [1 2]] | describe                                  # => table<a: int, b: int>
[[a b]; [1 2]] | peek | metadata access {|md| $md.peek }    # => {type: list, stream: false}
stor open | describe                                        # => SQLiteDatabase
stor open | peek | metadata access {|md| $md.peek }         # => {type: custom, stream: false}
```

So a table cannot be told from a list, and one custom value cannot be told from another — every plugin value is `custom`.
A branch that turns on either distinction is not convertible, and rewriting it with `peek` silently sends every table down the list arm.
Check what the branches actually separate before reaching for the idiom; `describe` is the right tool when the answer lives inside `table<…>`.

**`value` needs a count.** Bare `peek` stores `{type, stream}` and nothing else — there is no `value` to destructure.
`peek 1` (or more) adds one, but only for list-shaped input; a string, an int and a record never get one:

```nushell
[1 2 3] | peek 2 | metadata access {|md| $md.peek }   # => {type: list, stream: false, value: [1, 2]}
[] | peek 1 | metadata access {|md| $md.peek }        # => {type: list, stream: false, value: []}
"x" | peek 1 | metadata access {|md| $md.peek }       # => {type: string, stream: false}
```

With a count, then, the empty case is `value: []` rather than a missing field; `peek 2` is how `std-rfc/iter only` tells "exactly one" from "more than one".
An empty `{ }` body passes the input through.

**A site qualifies only if the value arrives by pipe, uncollected.**
`describe` on a named parameter, on a `let`-bound variable, or on a field pulled out of a record is not a dispatch site: the value is already in hand, so `peek` spares nothing and only lengthens the line.
`let x = $in` followed by uses of `$x` as *data* is the same case — converting it means restructuring the whole body inside `metadata access`, which is rarely worth it.
Applied across six of our modules, this left almost nothing: of 20 `describe` sites, 3 converted, 6 were branch-on-table-vs-list or on a custom value's name, and 11 were values already in hand.

### `items` for Record Iteration

```nushell
$record
| items {|k v|
    $v
    | str replace --regex '^\s*(\S)' '  $1'
    | str join (char nl)
    | $"($k):\n($in)"
}
```

### Safe Navigation with `?`

```nushell
$env.numd?.table-width? | default 120
$env.numd?.prepend-code?
```

### Cell-Paths Are Values

A cell-path is a first-class value, not just syntax inside `get`.
`$.` is the literal form, and two commands take it apart and put it back together:

```nushell
$.a.b | describe                        # => cell-path
$.a.b | split cell-path | get value     # => [a, b]
```

`split cell-path` yields one row per step — `{value, optional, insensitive}` — so a path can be rewritten with ordinary table commands and rebuilt with `into cell-path`:

```nushell
# make every step optional, so a missing path yields null instead of an error
let loose = $.a.b | split cell-path | update optional true | into cell-path
{} | get $loose        # => null

# build an accessor from data
let dynamic = ["users" 0 "name"]
    | each {|s| {value: $s, optional: false, insensitive: false} }
    | into cell-path
{users: [{name: "ada"}]} | get $dynamic   # => ada
```

A list index must stay an `int` in the `value` field — `"0"` as a string makes `get` look for a *column* named `0` and fail with `column_not_found`.

Use this instead of building a path as a string and interpolating it into `get`: the value form carries the optional and case-insensitive flags, and it cannot be mangled by a `.` inside a column name.
`split cell-path` is also how you render a path for an error message — `$col | split cell-path | get value | str join "."`.

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

## Error Construction

`error make` takes more than `msg`, and the extra fields are what turn a bare failure into a message the caller can act on.
The whole of `std/assert` is built on them.

```nushell
def "assert even" [n: int] {
    if $n mod 2 != 0 {
        error make {
            msg: "not an even number"
            label: {text: $"($n) is odd", span: (metadata $n).span}
            help: "pass a multiple of two"
            code: "demo::assert::not_even"
        }
    }
}
```

- `label` — one `{text, span}` record; `labels` is the plural form and takes a table, for pointing at two arguments at once.
  Both may appear in the same call and both render.
  Since 0.115 a label missing its `span: {start, end}` is an error rather than being silently replaced by the record's own span.
- `span: (metadata $n).span` is the important part.
  `metadata` on a *parameter* returns the span of the value **as the caller wrote it**, so the error underlines the caller's argument, not a line inside your command.
  That is the only way a custom `assert` can point where a built-in one does.
  **It holds for a direct call only.**
  Raise the same error one level down — in a helper the command calls — and the span is that inner call site, a line in your own module source.
  That is worse than no label: it points confidently at the wrong place.
  So in a layered module, only the commands a user actually types qualify; a helper raising the error gets `help:` and no label.
  Verified on 0.115.1: a `def helper [name] { … (metadata $name).span … }` called as `helper $name` underlines `helper $name` in the calling file, never the user's command line.
- `help` — renders as a `help:` line under the error.
  Put the fix here, not in `msg`.
- `code` — the machine-readable code (`nu::shell::type_mismatch` and friends).
  Set it when a caller might reasonably match on it.

For an error with no meaningful source location, `error make --unspanned {msg: "…"}` skips the span rather than pointing at something arbitrary.
**The flag and a label are mutually exclusive, and nothing warns.**
Under `--unspanned` the label is dropped and only `msg` and `help:` render, so the flag is not an independent switch to leave in place while adding a label — removing it is part of adopting one:

```nushell
# --unspanned kept — the label is silently swallowed
export def with-unspanned [n: int] {
    error make --unspanned {msg: "…" label: {text: "points here" span: (metadata $n).span} help: "the help line"}
}
# =>   x …
# =>   help: the help line

# --unspanned dropped — the caret appears, help: unchanged
export def without-unspanned [n: int] {
    error make {msg: "…" label: {text: "points here" span: (metadata $n).span} help: "the help line"}
}
# =>   x …
# =>  1 | without-unspanned 42
# =>    :                   ^| points here
# =>   help: the help line
```

Keep `--unspanned` wherever there is no caller argument to point at; drop it wherever there is one.

Two shorthands from 0.110 cover the cases that need none of the above:

```nushell
error make "something went wrong"   # string shorthand
{msg: "oops"} | error make          # record from the pipeline
```

Pass `metadata` a pipeline instead of a parameter to underline the *input*: `ls | metadata access {|m| error make {msg: "bad" label: {text: "here" span: $m.span}} }`.

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

### `@category` and `@search-terms` on Exported Commands

`@example` is not the only attribute worth writing.
`@category` groups the command in `help commands`; `@search-terms` adds words that `help commands --find` will match.
Both land in `scope commands`:

```nushell
@category math
@search-terms "multiply" "scale"
@example "double five" { 5 | double } --result 10
export def double []: int -> int { $in * 2 }
```

```nushell
scope commands | where name == 'double' | select category search_terms
# => [[category, search_terms]; [math, "multiply, scale"]]
```

**`@category` goes on everything exported through a `mod.nu`.**
It is not a guessing game — the command belongs to a group or it does not.
Skip internal helpers, where nobody is searching.

**`@search-terms` goes almost nowhere.**
`help commands --find` searches the name, the description and the search terms together — verified in `crates/nu-command/src/help/help_commands.rs:62`, which hands all three columns to the matcher.
So a term repeating a word already in the name or the description matches nothing new.
Delete it.

A term earns its place only when all three hold:

- a user would really type that word;
- it appears nowhere in the name or the description;
- you would be glad to see *this* command returned as the answer to it.

The third one is what rules out generic verbs.
`save`, `list`, `clear`, `add`, `output`, `text` each match half a module, so the search returns a page and the right command is no easier to find inside it.
Wider is not better: a term that widens the match without narrowing the answer costs more than it gives.

The tell for a bad set is a fixed count per command.
150 `@search-terms` lines were once added across these modules, four terms each, and all 150 were removed again — four is a quota being filled, not four words anyone would type.

- Bad — `@search-terms "save" "store" "put" "write"` on `kv set`: every word a synonym of the name.
- Good — `@search-terms jq ".." nested` on `std-rfc`'s `recurse`: another tool's vocabulary, which a Nushell name and description cannot contain.

Zero terms is the normal state.
`@deprecated "Use new-cmd" --since "0.105.0"` belongs in the same place when you retire a name.

### The Module's Own `example` Command

Export an `example` command and the module's `@example` attributes become a menu: tab-complete a slug, and the pipeline lands in the command line for the user to read, edit and run.

**Offer this for a module that has outgrown `help`, not for every module.**
The test is whether a useful pipeline crosses commands — one subcommand's output feeding the next — because that is the knowledge no single command's help can show.
A module with a handful of composing subcommands, typed by a user in the REPL, earns the menu.
A one-command module does not: its own `help` already shows those examples.
Neither does a library imported by scripts, since the paste needs a REPL buffer.

```nushell
claude-nu example                      # every example as a table: slug, description, pipeline
claude-nu example <TAB>                # the same rows as a menu, each slug next to its pipeline
claude-nu example search-every-project # writes that pipeline into the command line
```

The rows are not a second list to maintain.
They are the `@example` attributes the module's own commands already carry, read at runtime:

```nushell
const MODULE = 'claude-nu' # the only per-module literal — a module copying this file changes it and nothing else

export def example-table []: nothing -> table<slug: string, description: string, example: string> {
    let exported = scope modules | where name == $MODULE | get 0?.commands? | default []
    if ($exported | is-empty) { return [] }

    let examples = scope commands | where decl_id in $exported.decl_id | select decl_id examples

    $exported
    | join $examples decl_id
    | each {|cmd| $cmd.examples | each {|ex| {command: $cmd.name description: $ex.description example: $ex.example} } }
    | flatten
    | slugify-examples
}
```

**Read the module, not the names an import happened to produce.**
`scope commands | where name starts-with 'claude-nu '` looks equivalent and is the one thing that breaks.
`use claude-nu *` imports the commands unprefixed, so that filter returns `[]` and every example vanishes — silently, since an empty menu is a valid menu.
`scope modules` gives module-relative names and their `decl_id`, which both import forms share, so the table comes out identical under `use claude-nu` and under `use claude-nu *`.
`main` arrives there under the module's own name, so an example on the module itself is labelled `claude-nu`, not `main`.

**A pipeline that crosses commands hangs on the module's `main`.**
No single subcommand owns it, and `main` usually exists already as a signpost that names the subcommands.
Hanging the pipelines there as `@example` blocks replaces the copy such a `main` tends to keep in its help text: one source now reaches `help`, the menu, and `dotnu examples-update`.

**The paste is REPL-only, and the bare form is the fallback.**
`commandline edit --replace` has no buffer to write to in a script, so with no argument the command returns the table instead and composes like any other data.
The user runs the pipeline; the command only fills the line.

**Slugs come from the description**, so they read as a label rather than as an index nobody remembers.
Two rules keep that usable when the convention is copied: fall back to the command name when the description is empty, and number a repeated slug (`same`, `same-2`) instead of losing the second example.
Neither is hypothetical — `dotnu` writes `@example ''` on nearly all of its examples, so the first module to reuse this arrives with no descriptions at all.

**Keep the authored order** — the completer returns `{options: {sort: false} completions: ...}` (see the `nushell-completions` skill for that record form).
The order the module declares — its own pipelines first, then each command's — is the order a reader should meet them in, while alphabetical would follow whatever word a description happens to start with.

**The check lives on the authoring side, not here.**
`dotnu examples-update` runs each block and writes the real output back into `--result`, so a pipeline broken by a rename is caught there instead of being suggested to the user.
Do not build the table from `dotnu find-examples`: it returns no description and drops any example without a `--result`, while the menu needs the description and must show result-less examples too.

Working implementation, tests included: `example.nu` in [claude-nu](https://github.com/nushell-prophet/claude-nu).
Note that `nu-goodies` exports an unrelated bare `example` (it shares the command you just ran); this one is always reached through its module prefix, so the two coexist.

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

**Key pattern:** Nushell has no private/public distinction within a file.
Use a two-file pattern:

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

### Shadowing a Builtin: Reach the Real One with `%`

A module command may legitimately be named after a builtin — `assert length`, `assert str contains`, a `main update`.
Inside that module the bare name now resolves to the custom command, and the failure is indirect: the *other* modules this one imports were parsed with the name already bound, so an imported body calling the builtin breaks while pointing at a file you did not touch.

```nushell
# bad.nu
use ./helper.nu *
export def update [] { "custom update" }
```

```
Error: nu::parser::extra_positional
   ╭─[helper.nu:3:12]
 3 │     update file { cwd-relative }
   ·            ──┬─
   ·              ╰── extra positional argument
```

The error names `helper.nu`, a file that is correct and that you did not change, so bisecting it finds nothing.

**The fix is the `%` sigil, written wherever the builtin is called.**
`%name` resolves to the builtin regardless of what is shadowing it:

```nushell
# helper.nu — immune to whatever imports it
export def touch-rows []: table -> table {
    $in | %update file { cwd-relative }
}

# and in the shadowing file's own bodies
export def length [left: list right: int] {
    if ($left | %length) != $right { error make {msg: "wrong length"} }
}
```

Verified on 0.115.1 for all four cases: an imported helper whose importer shadows the name, a same-file shadow, a `def --env` body, and a multiword builtin (`%str contains`).

Two limits:
- `%` reaches **builtins only**.
  A shadowed custom command, alias or external is not recoverable this way.
- It has to be written at the call site, so it fixes code you control.
  A third-party module that spells the name bare still breaks; the answer there is to not take the builtin's name.

**On `alias "core length" = length`:** `std/assert` uses that instead, and it works, but it is not the modern answer — those aliases date to 2023-05-27 (`3005fe10e`), while `%` arrived in 0.112, and `nu-std` uses `%` nowhere.
Prefer `%`; it needs no declaration, survives being copied into another file, and says at the call site which command is meant.

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

Prefer comments that explain "why", not "what".
**Never remove existing comments**:

```nushell
# Good: explain non-obvious decisions
# I set variables here to prevent collecting $in var
let expanded_format = "\n```\n\nOutput:\n\n```\n"
```
