# New Nushell Features for Better Scripts (0.100 → 0.112)

Modern idioms and new capabilities to improve existing Nushell code.
Version noted as `(v0.NNN)`.

---

## Pipeline Flow

### `let` at end of pipeline (v0.110)

```nushell
# before
let files = ls | get name
# after
ls | get name | let files
```

### `let` mid-pipeline — capture without breaking flow (v0.111)

```nushell
http get $url | let data | get items | length
# $data holds the full response
```

### `each --flatten` — stream through without collecting (v0.108)

```nushell
# before: collects each closure output, then flattens
0..5..<25 | each {|e| slow-source ($e)..<($e + 5) } | flatten

# after: streams directly
0..5..<25 | each --flatten {|e| slow-source ($e)..<($e + 5) }
```

### `for` loops accept streams (v0.108)

No longer collects the source. Works with unbounded streams.

```nushell
for event in (watch . --glob=**/*.rs) { cargo test }
```

### `generate` with pipeline input — stateful `each` (v0.102)

```nushell
[1 2 3 4] | generate {|item, acc| {out: ($item + $acc), next: ($item + $acc)} } 0
```

### `watch` streams events as a table (v0.107)

```nushell
# before: required a closure
watch . {|op, path| if $op == Write { lint $path } }

# after: pipe into normal commands
watch . | where operation == Write and path like "*.md" | each { md-lint $in.path }
```

### `par-each` streams results as they complete (v0.112)

Unordered `par-each` no longer blocks until all items finish.

---

## Error Handling

### `try`/`catch`/`finally` (v0.111)

`finally` runs unconditionally — after success, after catch, even after `return`.

```nushell
def process [] {
    let tmp = mktemp
    try { do-work $tmp } finally { rm $tmp }
}
```

`finally` receives the value or error:

```nushell
try { 111 } finally {|v| print $v}
```

### Simplified `error make` (v0.110)

```nushell
error make "something went wrong"   # string shorthand
error make                          # bare error with source span
{msg: "oops"} | error make          # pipe input
```

### Automatic error chaining in catch (v0.110)

```nushell
try { error make "inner" } catch { error make "outer" }
# "outer" automatically wraps "inner"
```

### External file spans in errors (v0.110)

```nushell
error make {
    msg: "parse error"
    src: {path: "/tmp/config.yaml"}
    labels: [{text: "bad value", span: {start: 10, end: 15}}]
}
```

### `first --strict` / `last --strict` (v0.109)

Error on empty input instead of returning nothing.

```nushell
[] | first --strict  # => error (instead of silent null)
```

### Catch error record: `json` and `rendered` columns (v0.100)

```nushell
try { fail } catch {|e| $e.json | from json }  # structured access
try { fail } catch {|e| $e.rendered }           # pre-formatted string
```

---

## Data Manipulation

### `merge deep` — nested record merging (v0.101)

```nushell
{a: {x: 1}} | merge deep {a: {y: 2}}
# => {a: {x: 1, y: 2}}

{b: [1 2]} | merge deep --strategy=append {b: [3 4]}
# => {b: [1 2 3 4]}
```

### `chunk-by` — group consecutive elements (v0.101)

```nushell
[1 3 -2 -2 0 1 2] | chunk-by {|x| $x >= 0}
# => [[1, 3], [-2, -2], [0, 1, 2]]
```

### `compact` works on records (v0.108)

```nushell
# before
$record | transpose k v | where v != null | transpose -r

# after
{a: 1, b: null, c: 3} | compact   # => {a: 1, c: 3}
```

### `default --empty` (v0.103)

Returns default for empty strings, lists, records, binary — not just null.

```nushell
"" | default --empty "fallback"   # => "fallback"
```

### `default` with lazy closure (v0.105)

```nushell
ls | default { expensive_call } some_col
# closure only evaluated when needed, result cached
```

### `group-by` multiple groupers + `--to-table` (v0.101)

```nushell
$data | group-by color category --to-table
# => table with columns: color, category, items
```

### `group-by --prune` (v0.112)

Remove the grouping column from results.

```nushell
$table | group-by category --prune
```

### `uniq-by --keep-last` (v0.111)

```nushell
[[fruit count]; [apple 9] [apple 2] [pear 3]] | uniq-by fruit --keep-last
# => apple 2, pear 3
```

### `join --prefix` / `--suffix` (v0.111)

```nushell
$left | join $right key --suffix "_right"
```

### `drop column --left` (v0.111)

```nushell
$table | drop column 2 --left
```

### `move --first` / `--last` (v0.102)

```nushell
$table | move name --first
$table | move id --last
```

### `drop nth` with spread (v0.106)

```nushell
ls | drop nth ...[1 2 3]
```

### `update` with optional cell paths (v0.109)

```nushell
{a: 1} | update b? 2  # => {a: 1} (no error when path absent)
```

### Spread `null` as empty (v0.107)

Eliminates null-guard branches.

```nushell
let extra = if $cond { {key: val} } else { null }
{base: 1, ...$extra}   # null acts as empty record

[1 2 ...(null)]   # => [1 2]
```

### Table literal columns support variables (v0.108)

```nushell
let col = "name"
[[$col, age]; [Alice, 30]]
```

### Built-in commands accept `null` for optional params (v0.112)

Enables transparent forwarding in wrappers.

```nushell
def wraps-first [rows?: int] { [1 2 3] | first $rows }
wraps-first      # => 1
wraps-first 2    # => [1, 2]
```

---

## Strings & Parsing

### `str escape-regex` (v0.112)

```nushell
let safe = $user_input | str escape-regex
$data | where name like $"^($safe)$"
```

### `str replace` with closure (v0.109)

```nushell
"foo123bar" | str replace --regex '\d+' {|m| $m.0 | into int | $in * 2 | into string}
```

### `parse` with `_` placeholder (v0.105)

```nushell
"hello world" | parse "{word} {_}"   # discards second field
```

### `str length --chars` (v0.108)

```nushell
"hällo" | str length --chars  # => 5 (not byte count)
```

### `str expand` with zero-padded ranges (v0.103)

```nushell
"file{00..10}.txt" | str expand
```

### `into string --group-digits` (v0.103)

```nushell
1234567 | into string --group-digits  # => "1,234,567"
```

### `find --no-highlight` (v0.102)

```nushell
$data | find "term" --no-highlight  # no ANSI in output
```

### `char eol` — platform line ending (v0.103)

```nushell
char eol  # "\r\n" on Windows, "\n" elsewhere
```

---

## Dates & Time

### `date from-human` (v0.104)

```nushell
date from-human "next Friday at 6pm"
```

### `into datetime` from record (v0.104)

```nushell
{year: 2025, month: 3, day: 30, hour: 12, minute: 15, second: 59, timezone: "+02:00"}
| into datetime
```

### `into duration` from record, float, or hh:mm:ss (v0.104, v0.112)

```nushell
{week: 10, day: 1, hour: 2} | into duration
1.5 | into duration --unit day
"16:59:58" | into duration    # => 16hr 59min 58sec
```

### `timeit --output` (v0.110)

```nushell
timeit --output { some-command }  # => {time: 14328, output: <result>}
```

### `%J` / `%Q` date format specifiers (v0.108)

```nushell
date now | format date "%J_%Q"   # => 20250918_131144
```

### `seq date` accepts any duration increment (v0.102)

```nushell
seq date --begin 2025-01-01 --end 2025-01-02 --increment 6hr
```

---

## Type Safety & Command Metadata

### `oneof<...>` parameter type (v0.105)

```nushell
def foo [param: oneof<binary, string>] { .. }
```

### `@deprecated` attribute (v0.105)

```nushell
@deprecated "Use new-cmd" --since "0.105.0" --remove "0.110.0"
def old-cmd [] { ... }
```

### `@example`, `@search-terms`, `@category` (v0.103)

```nushell
@example "double 5" { 5 | double } --result 10
@search-terms [multiply scale]
@category math
def double []: [int -> int] { $in * 2 }
```

### `describe --detailed` (v0.104)

Returns Rust type, Nushell type, and value.

### `get` is const-evaluable (v0.102)

```nushell
const val = [a b c] | get 2  # works at parse time
```

---

## HTTP

### Auto verb detection (v0.106)

```nushell
http https://example.com            # GET (no body)
http https://example.com {data: 1}  # POST (body present)
```

### Auto scheme (v0.105)

```nushell
http get example.com   # prepends http://
http get :8000         # => http://localhost:8000
```

### Connection pooling (v0.110)

```nushell
http get --pool https://api.example.com/a
http get --pool https://api.example.com/b
```

### Response metadata — no `--full` needed (v0.108)

```nushell
http get --allow-errors $url
| metadata access {|m|
    if $m.http_response.status != 200 { error make "failed" } else { }
}
| lines | each { from json }
```

### Redirect tracking (v0.107)

```nushell
http get --full $url | get urls   # redirect chain
```

### Unix domain sockets (v0.109)

```nushell
http get -U /var/run/docker.sock http://localhost/containers/json
```

### `url parse --base` (v0.112)

```nushell
"/path/page" | url parse --base "https://example.com"
```

### `url split-query` (v0.100)

```nushell
"a=1&b=2" | url split-query  # => [[key, value]; [a, 1], [b, 2]]
```

---

## Completions

### `@complete` attribute (v0.108)

Attach a completer to an entire command.

```nushell
@complete external
def --wrapped jc [...args] { ^jc ...$args | from json }

@complete my-completer
def go [direction] { ... }
```

### Inline list completions (v0.108)

```nushell
# before: separate completer function
def dirs [] { [left up right down] }
def go [dir: string@dirs] {}

# after: inline
def go [dir: string@[left up right down]] {}
```

### Substring algorithm (v0.104)

```nushell
$env.config.completions.algorithm = "substring"
```

---

## Commands & Scripts

### `%` sigil for built-ins (v0.112)

Call the original even when shadowed.

```nushell
def ls [] { echo "custom" }
%ls  # => real ls output
```

### Command group aliasing (v0.111)

```nushell
alias pl = polars
ps | pl into-df | pl select [(pl col name)] | pl collect
```

### `path self` (v0.101)

```nushell
const this_file = path self
const this_dir = path self .
```

### Background jobs (v0.103)

```nushell
job spawn { long-task | save result.txt }
job list
job kill $id
```

### Inter-job messaging (v0.104)

```nushell
job send $target_id "hello"
job recv   # blocks until message arrives
```

### `unlet` (v0.110)

```nushell
let big = open huge.csv
# ... process ...
unlet $big
```

### `explore regex` — interactive regex TUI (v0.109)

```nushell
open file.txt | explore regex
```

---

## Serialization & Formats

### `to nuon --raw-strings` (v0.110)

```nushell
"path\\to\\file" | to nuon --raw-strings  # => r#'path\to\file'#
```

### `to nuon --list-of-records` (v0.112)

```nushell
ls | to nuon --list-of-records --indent 2
# => [{name: "foo", ...}, {name: "bar", ...}]
```

### `to md --list` (v0.110)

```nushell
[a b c] | to md --list ordered   # numbered list
[a b c] | to md --list none      # plain text (old behavior)
```

### `to md` escapes pipe in cells (v0.108)

No more broken markdown tables from data containing `|`.

### `from md` — structured markdown parsing (v0.112)

```nushell
open README.md  # returns AST, not raw string
open --raw README.md  # for raw string
```

### `to text --no-newline` (v0.100)

```nushell
[a b] | to text -n  # no trailing newline
```

### `format number --no-prefix` (v0.106)

```nushell
255 | format number --radix 16 --no-prefix  # => "ff"
```

### `bytes split` — streaming binary split (v0.102)

```nushell
open --raw file | bytes split 0x[00] | each { decode }
```

### `source null` / `use null` — conditional sourcing (v0.102)

```nushell
const file = if ("local.nu" | path exists) { "local.nu" } else { null }
source $file  # no-op when null
```

---

## Standard Library (`std`, `std-rfc`)

### `std/clip` — clipboard (v0.106, promoted from std-rfc)

```nushell
use std/clip
"data" | clip copy
clip paste
```

### `std-rfc/iter recurse` — recursive descent (v0.105)

Equivalent to jq `..`. Flattens nested structures.

```nushell
use std-rfc/iter *
{a: {b: 1, c: [2, 3]}} | recurse | where ($it.item | describe) == "int"
```

### `std-rfc/iter only` — assert exactly one element (v0.106)

```nushell
use std-rfc/iter *
ls | where name == "foo.txt" | only modified
```

### `std-rfc/random choice` (v0.107)

```nushell
use std-rfc/random
$list | random choice 3
```

### `std-rfc/str dedent` (v0.103)

```nushell
use std-rfc/str *
"  hello\n  world" | dedent  # => "hello\nworld"
```

### `std-rfc/kv` — key-value store (v0.103)

SQLite-backed, supports named tables (v0.107).

```nushell
use std-rfc/kv *
"data" | kv set mykey
kv get mykey
kv set key val --table project_settings
```

### `std-rfc/conversions` (v0.103)

`into list`, `columns-into-table`, `name-values`, `record-into-columns`, `table-into-columns`.

### `log set-level` (v0.102)

```nushell
use std; log set-level DEBUG
```

---

## Tables & Display

### `input list` overhaul — fuzzy, multi-select, per-column (v0.111)

```nushell
ls | input list --fuzzy --multi
ls | input list --fuzzy --per-column
```

### Table modes: `"single"` (v0.105), `"double"` (v0.106)

```nushell
$env.config.table.mode = "single"   # thin lines, sharp corners
$env.config.table.mode = "double"   # double-line box drawing
```

### `config use-colors` (v0.102)

```nushell
if (config use-colors) { $"(ansi green)ok(ansi reset)" } else { "ok" }
```

### `random uuid` with version (v0.103)

```nushell
random uuid -v 7  # time-ordered UUID v7
```

### `$env.NU_BACKTRACE = 1` (v0.103)

Enable nushell-level backtraces for debugging error chains.

### Metadata: pipeline span (v0.106), `--path-columns` (v0.111)

```nushell
# point errors at pipeline source
ls | metadata access {|m| error make {msg: "bad", label: {text: "here", span: $m.span}}}

# enable path rendering in custom tables
glob * | wrap path | metadata set --path-columns [path]
```
