# Nushell Migration Guide (0.100 → 0.113)

When updating Nushell scripts, consult this reference for breaking changes,
renamed commands, and new idioms. Versions noted as `(v0.NNN)`.

---

## Renamed & Removed Commands

| Old | New | Version |
|-----|-----|---------|
| `range` | `slice` | removed 0.103 |
| `into bits` | `format bits` | removed 0.103 |
| `fmt` | `format number` | removed 0.103 |
| `split-by` | `group-by` (multiple groupers) | removed 0.102 |
| `date to-record` | `into record` | removed 0.102 |
| `date to-table` | `into record \| transpose \| transpose -r` | removed 0.102 |
| `utouch` | `touch` | removed 0.102 |
| `into value` (type inference) | `detect type` | 0.108 |
| `into value --columns` | `detect type --columns` | removed 0.112 |
| `random dice` (built-in) | `use std/random; random dice` | removed 0.112 |
| `filter` | `where` (accepts stored closures) | deprecated 0.105 |
| `do -s` / `do -p` | `do --suppress-errors` / long form | removed 0.104 |
| `do --ignore-shell-errors` | `do --ignore-errors (-i)` | deprecated 0.101 |
| `do --ignore-program-errors` | `do --ignore-errors (-i)` | deprecated 0.101 |
| `job tag` | `job describe` | 0.112 |
| `polars fetch` | (removed, no replacement) | 0.108 |

### Renamed Flags

| Command | Old Flag | New Flag | Version |
|---------|----------|----------|---------|
| `get`/`select`/`reject` | `--ignore-errors (-i)` | `--optional (-o)` | 0.106 |
| `du` | `--all (-a)` | `--long (-l)` | 0.101 |
| `watch` | `--debounce-ms` | `--debounce` (duration) | removed 0.112 |
| `metadata set` | `--merge` | closure form | removed 0.112 |
| `metadata set` | `--datasource-ls` | `--path-columns [name]` | removed 0.113 (deprecated 0.111) |
| `kill` | `-0` / `-9` shorthand | `-s 0` / `-s 9` (long signal form) | removed 0.113 |
| `watch` | closure argument | bare `watch path` stream + `for`/`each` | deprecated 0.113 |
| `grid` | implicit record handling | explicit `(column)` argument | deprecated 0.113 |

---

## Arithmetic & Operators

### Integer division returns float (v0.100)

```nushell
# before: 2 / 2 => int
# after:  2 / 2 => float (2.0)
# use // for integer floor division
```

### Floor division promotes to float (v0.100)

```nushell
1 // 1.0 | describe  # => float (was int)
```

### `mod` is now floored, not truncated (v0.100)

```nushell
8 mod -3   # => -1 (was 2)
```

### Float display always includes decimal (v0.106)

```nushell
4 / 2  # => 2.0 (was 2). Affects to csv, to json, to md round-trips
```

### Compound assignment type checking (v0.106)

```nushell
mut x = 1
# $x /= 2  # error: int / int = float, can't assign float to int
```

### New operators

| Operator | Meaning | Version |
|----------|---------|---------|
| `like` / `not-like` | aliases for `=~` / `!~` | 0.100 |
| `has` / `not-has` | reverse-operand `in` / `not-in` | 0.102 |
| `not-starts-with` | negated starts-with | 0.108 |
| `not-ends-with` | negated ends-with | 0.108 |

```nushell
# has — useful in where clauses
$table | where children has "e"   # instead of: where ("e" in $it.children)
```

---

## Syntax Changes

### `++` is concatenation only (v0.101)

```nushell
# before: [1 2 3] ++ 4 => [1 2 3 4]
# after:  [1 2 3] ++ [4]  or  [1 2 3] | append 4
```

### `timeit` requires a closure (v0.101)

```nushell
timeit { ls }   # ok
# timeit (ls)   # error
```

### Closure params must be terminated by `|` (v0.100)

```nushell
{ |a| $a }  # ok
# { |a $a }  # parse error
```

### Stricter command signatures (v0.101)

```nushell
# before: def foo [] -> string { '' }  (silent failure)
# after:  def foo []: any -> string { '' }  (input type required)
```

### `let` at end of pipeline (v0.110)

```nushell
ls | get name | let files    # equivalent to: let files = ls | get name
```

### `let` mid-pipeline pass-through (v0.111)

```nushell
"hello" | let msg | str length  # => 5; $msg = "hello"
```

### `%` sigil for built-in commands (v0.112)

```nushell
def ls [] { echo duck }
ls     # => duck
%ls    # => real ls output
```

### `$nu` paths renamed (v0.110)

```nushell
# before: $nu.temp-path / $nu.home-path
# after:  $nu.temp-dir  / $nu.home-dir
```

---

## Type System & Strictness

### Run-time pipeline input type checking (v0.102)

Previously parse-time only. Now also enforced at run-time through `any`-typed intermediaries.

### `string` ↔ `glob` implicit casting (v0.108)

Strings and globs are subtypes of each other — no more `cant_convert` when passing string to glob param.

### `oneof<...>` type for parameters (v0.105)

```nushell
def foo [param: oneof<binary, string>] { .. }
```

### `describe` reports `datetime` (v0.104)

```nushell
date now | describe  # => "datetime" (was "date")
```

### `each` passes through `null` (v0.107)

```nushell
# before: null | each { "something" } => "something"
# after:  null | each { "something" } => null
```

### Collecting streams with errors raises immediately (v0.108)

```nushell
# before: errors collected into list<error>
# after:  first error thrown immediately
```

### Immediate error return on error values (v0.102)

Error values passed as pipeline input or arguments now cause immediate return.

### `pipefail` on by default (v0.111)

`$env.LAST_EXIT_CODE` reflects rightmost non-zero exit in a pipeline.

### Experimental `enforce-runtime-annotations` (v0.108)

Catches type annotation violations at runtime when enabled.

---

## Command Behavior Changes

### `find` is case-sensitive by default (v0.107)

```nushell
["Foo" "bar"] | find foo       # no match
["Foo" "bar"] | find -i foo    # matches "Foo"
```

### Cell-paths are case-sensitive by default (v0.105)

```nushell
$record | get Content-Type     # exact match required
$record | get Content-Type!    # case-insensitive (! suffix)
# $env remains always case-insensitive
```

### `split list` keeps empty sublists (v0.103)

```nushell
[1 0 0 3] | split list 0  # => [[1] [] [3]]  (was [[1] [3]])
```

### `match` no longer executes returned closures (v0.103)

```nushell
match 1 { _ => {|| print hi} }  # returns closure (was: executed it)
```

### `split column` uses 0-indexed names (v0.109)

```nushell
'a b c' | split column ' '  # columns: column0, column1, column2 (was 1-indexed)
```

### `url parse` params is a table (v0.100)

```nushell
# before: params was a record {a: 1, b: 2}
# after:  params is a table [[key, value]; [a, 1], [b, 2]]
```

### `overlay list` returns table (v0.107)

```nushell
# before: overlay list | last => "name"
# after:  overlay list | last | get name => "name"
```

### `http --max-time` takes duration (v0.100)

```nushell
http get --max-time 30sec $url   # was: --max-time 30
```

### `format filesize` is case-sensitive (v0.102)

```nushell
1000 | format filesize kB    # metric
1000 | format filesize KiB   # binary
```

### `format bits` outputs big endian (v0.107)

```nushell
# Use --endian native to restore old (pre-0.107) behavior
258 | format bits --endian native
```

### `parse` unmatched groups return `null` (v0.106)

```nushell
# before: unmatched optional capture group => ""
# after:  => null
```

### `glob`/`mv`/`cp`/`du` dotfile handling (v0.110)

```nushell
# * no longer matches dotfiles in mv, cp, du
cp --all * /tmp   # use --all to include dotfiles
```

### `open *.md` returns structured data (v0.112)

```nushell
# before: open file.md => raw string
# after:  open file.md => parsed AST (from md)
open --raw file.md   # for raw string
```

### `from md` default output is concise rows (v0.113)

```nushell
# before (0.112): open file.md => full AST (type, position, attrs, children)
# after  (0.113): open file.md => concise human-friendly rows
open file.md --raw | from md --verbose   # full AST as before
```

### `parse` no longer auto-splits external streams (v0.113)

Byte/string streams from external processes are no longer implicitly split by
lines before `parse`. Pipe through `lines` first.

```nushell
# before
^cat file.log | parse -r '(?P<level>\w+)\s+(?P<msg>.+)'
# after
^cat file.log | lines | parse -r '(?P<level>\w+)\s+(?P<msg>.+)'
```

### `kill -0` no longer accepted as shorthand (v0.113)

`kill -0` used to send signal 0 but now errors (was also a footgun — could
terminate nushell itself). Use the long form.

```nushell
# before: kill -0 1234
# after:  kill -s 0 1234   # signal 0 = check if process exists
# same for: kill -9 pid => kill -s 9 pid
```

### `mkdir -v` / `mv -v` / `rm -v` return tables (v0.113)

Verbose flags now return queryable structured tables instead of human text.
Scripts that parsed the text output need to consume the table columns.

```nushell
mkdir -v a/b/c
# => [[path created error]; [a true ""] [a/b true ""] [a/b/c true ""]]

mv -v src dst   # columns: source, destination, message
rm -v old.txt   # columns: path, …
```

### `from xlsx --header-row` default change (v0.113)

Default is now the first non-empty row (was row 0). Pass `--header-row null`
for no header, or an explicit 0-indexed integer to restore old behavior.

```nushell
open data.xlsx                          # first non-empty row as header
open data.xlsx | from xlsx -r null      # treat all rows as data
open data.xlsx | from xlsx -r 0         # old default
```

### `to yaml` now quotes ambiguous string values (v0.113)

Previously emitted bare `off` / `on` / `yes` / `no` / `0.0.0.0:8444` etc.,
which re-parse as booleans or invalid YAML. Now wrapped in single quotes.
Scripts that compared the round-tripped text need updating.

```nushell
'{"value": "off"}' | from json | to yaml
# before: value: off
# after:  value: 'off'
```

### `to csv` / `to tsv` now stream and fail on schema drift (v0.113)

Rows are written as they arrive instead of buffered. If a later row
introduces a new column, the export errors mid-stream.

```nushell
# fix 1: declare columns up front
$rows | to csv --columns [a b c]
# fix 2: collect first when the schema is variable
$rows | collect | to csv
```

### `ls` no longer sets `source` metadata (v0.113)

Paired with the `metadata set --datasource-ls` removal. Code that inspected
`$result | metadata | get source` and matched `"ls"` needs another signal.

### `into datetime` no longer parses human strings (v0.104)

```nushell
# before: "next Friday" | into datetime
# after:  "next Friday" | date from-human
```

### `to md` formats lists as unordered (v0.110)

```nushell
[a b c] | to md             # => "* a\n* b\n* c"
[a b c] | to md --list none # old behavior
```

### `str join` datetime formatting (v0.104)

Datetime values now format as RFC2822/RFC3339. Use `format date` first for custom format.

### `http post` sends pretty JSON (v0.107)

Body size increased. Use `to json -r` before piping if compact JSON needed.

### `mktemp` without template (v0.111)

Creates in tmpdir instead of current directory.

---

## New Commands & Idioms

### Replace old patterns

| Old pattern | New idiom | Version |
|-------------|-----------|---------|
| `"next Friday" \| into datetime` | `"next Friday" \| date from-human` | 0.104 |
| `"123" \| into value` | `"123" \| detect type` | 0.108 |
| `$table \| into value` | `$table \| update cells { detect type }` | 0.108 |
| `$data \| filter $f` | `$data \| where $f` | 0.105 |
| `{ \|\| } \| to json` | `{ \|\| } \| to json --serialize` | 0.103 |
| `get --ignore-errors key` | `get --optional key` | 0.106 |
| manual external completer match | `@complete fish-completer; extern git []` | 0.108 |
| `def foo [x: string@completer_fn]` | `def foo [x: string@[a b c]]` (inline) | 0.108 |
| `find ... \| result` | `find --no-highlight ...` (strip ANSI) | 0.102 |
| manual `http get --full \| get headers` | `http get url \| metadata \| get http_response` | 0.108 |

### Background jobs (v0.103, experimental)

```nushell
job spawn { long-task }
job list
job kill $id
```

### Custom command attributes (v0.103+)

```nushell
@example "double 2" { 2 | double } --result 4
@deprecated "Use new-cmd" --since "0.105.0"
@search-terms ["math" "multiply"]
@category "math"
@test
def "test add" [] { assert equal (1 + 1) 2 }
```

### `parse` with `_` placeholder (v0.105)

```nushell
"hello world" | parse "{word} {_}"   # ignores second field
```

### `default --empty` (v0.103)

Returns default for empty strings/lists/records/binary, not just null.

### `try..catch..finally` (v0.111)

```nushell
try { risky } catch { handle } finally { cleanup }
```

### `timeit --output` (v0.110)

```nushell
timeit --output { 'text' }  # => {time: ..., output: text}
```

### `str escape-regex` (v0.112)

```nushell
".*" | str escape-regex  # => "\.\*"
```

### `into duration` parses hh:mm:ss (v0.112)

```nushell
"16:59:58" | into duration  # => 16hr 59min 58sec
```

### Spread `null` as empty (v0.107)

```nushell
[1 2 ...(null)] == [1 2]   # true
{a: 1 ...(null)} == {a: 1} # true
```

### `source null` / `use null` for conditional sourcing (v0.102)

```nushell
const file = if ($file | path exists) { $file } else { null }
source $file
```

### `http` auto-detects verb (v0.106)

```nushell
http https://example.com             # GET (no body)
http https://example.com {data: 1}   # POST (has body)
```

### `http` auto-prepends scheme (v0.105)

```nushell
http get example.com    # => http://example.com
http get :8000          # => http://localhost:8000
```

---

## Configuration Changes

### Filesize config restructured (v0.102)

```nushell
# before:
$env.config.filesize.format = "auto"
$env.config.filesize.metric = true

# after:
$env.config.filesize.unit = "metric"   # or "binary", "kB", "KiB", etc.
$env.config.filesize.precision = 1     # decimal places, or null
```

### Startup config overhaul (v0.101)

- `default_env.nu` / `default_config.nu` always loaded before user files
- `$env.config` always exists at startup with defaults
- `const NU_LIB_DIRS` replaces `$env.NU_LIB_DIRS`
- `const NU_PLUGIN_DIRS` replaces `$env.NU_PLUGIN_DIRS`
- PATH conversion handled internally — remove `ENV_CONVERSIONS` for PATH
- Hooks fields are non-optional, default to `[]` or `{}`
- User autoload: `($nu.default-config-dir)/autoload/*.nu` sourced at startup (v0.102)

### `PROMPT_*` not inherited (v0.103)

`PROMPT_COMMAND` etc. from parent process are ignored.

### Completion config changes

| Change | Version |
|--------|---------|
| Custom completer `sort: true` uses `$env.config.completions.sort` (was alphabetical) | 0.101 |
| Missing `sort` field defaults to `true` (was `false`) | 0.101 |
| Custom completer `case_sensitive` inherits from config (was `true`) | 0.102 |
| External completers no longer used for internal commands | 0.103 |
| `positional: false` → `completion_algorithm: "substring"` | deprecated 0.104 |
| `$env.config.completions.algorithm = "substring"` option | 0.104 |
| External completer fallback requires `null` return (not any invalid value) | 0.102 |

### `display_output` hook (v0.101)

If set, solely responsible for formatting — `table` no longer runs on top. Set to `null` for default `table` behavior.

### Hook execution order changed (v0.107)

`env_change` → `pre_prompt` → `PROMPT_COMMAND` (was: `pre_prompt` first).

### EditCommand renames (v0.108)

`cutinside` → `cutinsidepair`, `yankinside` → `copyinsidepair` in keybinding config.

### Env var names case-insensitive (v0.111)

All `$env` lookups are case-insensitive on all OSes.

### History config fields locked after REPL start (v0.113)

These fields are read once at startup by reedline; setting them from the
REPL is now a hard error instead of silently ignored. Set them in
`config.nu` (or via `--config` / env vars) and restart.

```nushell
# locked: error if assigned from REPL
$env.config.history.path
$env.config.history.max_size
$env.config.history.file_format
$env.config.history.isolation

# still mutable from REPL — re-read every prompt
$env.config.history.sync_on_enter
$env.config.history.ignore_space_prefixed
```
