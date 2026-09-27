---
name: nushell-completions
description: This skill should be used when generating Nushell custom completions, writing completer functions, adding tab-completion to extern commands, using string@completer annotations, inline @[...] completion lists, the @complete and @interactive attributes, completer inputs (token, place, buffer), external completers such as carapace, menu source closures, or `commandline complete --input` for testing. Also for migrating completers that trigger the "Positional completer input deprecated" warning (old `context`/`pos`/`spans` parameters). Relevant when the user asks to "add completions," "write a completer," "create an extern with tab completion," "set up carapace," or "build context-aware argument suggestions" in Nushell.
---

# Nushell Custom Completions

Generate completions for Nushell commands following these patterns.
The completer model below is the 0.116 one: one input record and one output format for parameter completers, command-wide completers, the external completer and menu sources.

## Quick Reference

- `string@[a b c]` — inline static list (0.108+)
- `string@$const_list` — const variable (0.108+)
- `string@completer` — custom completer command (all versions)
- `@complete completer` — command-wide completer (0.108+)
- `@complete external` — send a whole command to `$env.config.completions.external.completer` (0.108+)
- `@interactive` — the completer owns the terminal, for `input list` or `fzf` pickers (0.116+)
- `commandline complete` — reuse nushell's own suggestions (0.114+); `--input` shows what a completer receives (0.116+)

## Inline Completions (Nu 0.108+)

Simplest approach for static options:

```nu
# Inline list directly in signature
def go [direction: string@[left up right down]] { $direction }

# Using const variable
const directions = [left up right down]
def go2 [direction: string@$directions] { $direction }
```

Builtins use the same pattern — since 0.115 the unit argument of `format duration` and `format filesize` completes from such a list (`1sec | format duration <Tab>` offers `day`, `hr`, `min`, ...).

## Completer Inputs (Nu 0.116+)

A completer asks for its inputs by **naming** its positional parameters.
Three names are recognized, in any order, each optional:

- `token: record` — the word at the cursor: `text`, `kind` (`head`, `flag` or `value`), `span` (`{start, end}` in the buffer)
- `place: record` — where the completion happens:
  - `cursor` — the cursor offset in `buffer`
  - `target` — `{start, end}`, the range a suggestion replaces
  - `kind` — `positional`, `flag-value`, `flag-name`, `external-arg`, `command`, `variable`, ...
  - `index` — for `positional` (index into the signature) and `external-arg` (argument number, the head not counted)
  - `flag` — for `flag-value`, the long flag name
  - `shape` — the declared type of the slot, e.g. `string`; absent for a bare external
  - `command` — the command at the cursor as a list of shell words; details below
- `buffer: string` — the whole line from its start up to the cursor, including text before pipes and `;`

A completer with no parameters gets nothing and still works.

Print the record a completer would receive, without running any completer:

```nu
'git checkout mai' | commandline complete --input
# => {token: {text: mai, kind: value, span: {start: 13, end: 16}},
#     place: {cursor: 16, target: {start: 13, end: 16}, kind: external-arg, index: 1, command: [git, checkout, mai]},
#     buffer: "git checkout mai"}
```

`place.command` is the command the cursor is in, not the whole line: after `ls | ^foo --bar b` it is `[foo, --bar, b]`.
Aliases are expanded, and an unfinished argument stays one word (`foo [a b` gives `[foo, "[a b"]`).
An empty slot adds a trailing `""` (`git checkout ` gives `[git, checkout, ""]`).
**The head is one item even when it has spaces.**
For a bare external, `git checkout mai` is `[git, checkout, mai]`.
Once `extern "git checkout"` (or a `def "git checkout"`) exists, the same line is `["git checkout", mai]`, with `kind: positional, index: 0, shape: string`.

### Deprecated inputs (still work, warn)

The pre-0.116 parameters — `[context: string]`, `[context: string, pos: int]`, `[spans: list<string>]`, and `{|buffer, position|}` for menus — still receive their old values, but emit `nu::shell::deprecated` ("Positional completer input deprecated") on first use.
This is a bridge, not a break; the warning says it will be removed in a future release.
Only the first two parameters get the bridge: an unrecognized name there receives the old value and triggers the warning, and one in the third slot or later receives `nothing`.

Migration:

- `[context: string]` → `[place: record]` and read `$place.command`.
  The old `context` held only the current command's text (`cmd a` in `ls | cmd a`), while `$buffer` is the whole line (`ls | cmd a`), even though the warning's help suggests `$buffer`.
- `pos: int` → `$place.cursor`
- `[spans: list<string>]` (command-wide or external) → `[place: record]` and read `$place.command`
- `{|buffer, position| ...}` menu source → `{|buffer, place| ...}` and `$place.cursor`

## Completer Output (Nu 0.116+)

A completer may return:

- `null` — decline: the next source answers, usually file completion
- a string, or a list of strings
- suggestion records, alone or in a list: `{value: v, description: "..."}`
- an envelope record: `{completions: [...], options: {...}, fallback: true}`

`null`, `[]` and an error differ:

- `null` declines, so file completion takes over.
- `[]` answers with nothing — use it for an argument that takes any value.
- A parameter completer that fails shows no suggestions (0.116+; 0.115.1 fell back to files).

Filtering by default:

- A **parameter** completer (`string@c`) returns every candidate; nushell filters and sorts them against the typed text.
- A **command-wide** (`@complete`) or **external** completer is expected to filter by itself: its list is shown as returned, unfiltered and in its own order.
- Set `options.filter` to change either default — except that `filter: true` is ignored for an `@complete` completer in 0.116.0 (its list stays unfiltered).

Envelope keys:

- `completions` — the list, in any of the forms above
- `fallback` — `true` shows these results *and* continues to the next source (e.g. file completion); default `false`
- `options`:
  - `filter` — `true`/`false`, default by completer kind (above)
  - `sort` — `true`/`false`, default `true`; `false` keeps the returned order
  - `case_sensitive` — default from `$env.config.completions.case_sensitive`
  - `completion_algorithm` — `prefix`, `substring` or `fuzzy`; default from `$env.config.completions.algorithm`
  - `match_description` — `true` also matches the typed text against `description`

Suggestion record fields:

- `value` — the text to insert (required)
- `description` — shown in the menu
- `display_override` — shown in the menu instead of `value`
- `style` — a color name (`green`) or a record `{fg: green, bg: black, attr: b}`
- `append_whitespace` — `true` adds a space after the inserted value
- `span` — `{start, end}` to replace a range other than the token

```nu
def "nu-complete presets" [] {
    {
        completions: [
            {value: main description: "default branch"}
            {value: release description: "release branch"}
        ]
        options: {completion_algorithm: substring match_description: true}
        fallback: true   # file names are offered too
    }
}
def deploy [preset: string@"nu-complete presets"] { }
```

## Custom Completer Functions

```nu
# Simple completer
def "nu-complete git remotes" [] {
    git remote | lines
}

# With descriptions
def "nu-complete git branch-subjects" [] {
    git branch --format='%(refname:short)|%(subject)'
    | lines
    | split column '|' value description
}

# Context-aware: the branch list depends on the remote typed before it
def "nu-complete git branches" [place: record] {
    let remote = $place.command | get 1?   # item 0 is the command name
    if $remote in (git remote | lines) {
        git branch --remotes --format='%(refname:short)' | lines
        | where { str starts-with $remote }
    } else {
        git branch --format='%(refname:short)' | lines
    }
}

def my-cmd [
    remote: string@"nu-complete git remotes"
    branch: string@"nu-complete git branches"
] { }
```

One completer can serve several slots by branching on `place`; returning nothing for a slot declines it:

```nu
def "nu-complete build" [place: record] {
    if $place.kind == flag-value and $place.flag == profile { [debug release] }
}
def build [--profile: string@"nu-complete build", target?: string@"nu-complete build"] { }
```

## Command-Wide Completers (Nu 0.108+)

`@complete` gives one completer every argument of a command, flags included:

```nu
# The completer sees the whole command at the cursor
def "nu-complete tasks" [place: record] {
    let typed = $place.command | last
    [build test lint] | where { str starts-with $typed }   # command-wide: filter it yourself
}

@complete "nu-complete tasks"
def --wrapped task [...args] { }

# Hand an internal wrapper to the global external completer
@complete external
def --wrapped jc [...args] { ^jc ...$args | from json }
```

## Interactive Completers (Nu 0.116+)

Completers run on a background worker.
A completer that needs the terminal — `input list`, `fzf` — must carry `@interactive`; it then runs on the line editor thread, which waits until the picker returns.
A picker may return a bare string: it becomes the one suggestion and is inserted.
Return one value from a picker.
When an interactive completer returns several items with a common prefix, the prefix is inserted and the completer runs a second time on the longer text — a picker would open twice.

```nu
@interactive
def "nu-complete pick-file" [token: record] {
    ls | get name | input list --fuzzy
}

def open-file [path: string@"nu-complete pick-file"] { open $path }
```

`@interactive` results are never cached, so the picker opens again on every Tab.
Outside the REPL, `commandline complete` refuses to run it (`nu::shell::interactive_completer_needs_a_terminal`); test it with `commandline complete --input`.
The external completer is a closure and cannot carry the attribute: make its **last** call an `@interactive` command (`{|place| my-picker $place }`).
A pipe after that call (`my-picker $place | first`) hides it, and the picker runs in the background.

## External Completer

`$env.config.completions.external.completer` is a closure with the same inputs and outputs as any completer.
It runs for bare external commands and for commands marked `@complete external`.
An `extern` without `@complete external` does not use it.

Carapace, in the form that survives multi-word `extern` names:

```nu
$env.config.completions.external.completer = {|place|
    # Why: an `extern "git checkout"` arrives as ["git checkout", ...]; split only the head
    let argv = ($place.command.0 | split row ' ') ++ ($place.command | skip 1)
    carapace $argv.0 nushell ...$argv | from json
}
```

The shorter `carapace $place.command.0 nushell ...$place.command` works for bare externals and aliases.
With `@complete external` on `extern "git checkout"`, it runs `carapace "git checkout" nushell "git checkout" mai`.
Don't write `$place.command | split row ' '`: it also splits arguments that contain spaces.

Return `null` to decline (file completion answers); `{completions: [...], fallback: true}` adds file completion under your list.

## Menu Sources (Nu 0.116+)

A `source` closure in `$env.config.menus` takes the same named inputs:

```nu
$env.config.menus ++= [{
    name: words_menu
    only_buffer_difference: false
    marker: "? "
    type: {layout: list, page_size: 10}
    style: {}
    source: {|token| [one two three] | where { str starts-with $token.text } }
}]
```

The old `{|buffer, position| ...}` form triggers the deprecation warning after the menu closes; replace `$position` with `$place.cursor` (`{|buffer, place| ...}`).

## Completion Caching (Nu 0.115+)

Completion results survive across prompts.
`$env.config.completions.cache_size` caps how many entries are kept (default `100`, least-recently-used eviction), and `0` turns the cache off.

Parameter completers are cached too: a completer called at the same typed text on a later prompt is not run again.
An entry is dropped when the completion environment changes — nushell fingerprints the cwd, the cwd's modification time, `$env.PATH`, the number of known declarations and `$env.config`.
So a completer that writes a file into the cwd invalidates its own entry.
Two things follow for a completer that shells out for live data:

- Data that changes without touching any of those (a new git branch, say) can be served stale until something else invalidates the entry.
- While iterating on a completer, set `$env.config.completions.cache_size = 0` so you always see what the current code returns.

## `commandline complete` (Nu 0.114+)

Returns the suggestions nushell itself would offer for a string, cursor at the end; without piped input it completes the current commandline.
Use it to test completers from a script (an external completer set earlier in the same script is used since 0.116), and inside completers to reuse built-in sources:

```nu
# What a completer at this spot receives (0.116+); runs no completer
'git checkout mai' | commandline complete --input

# All suggestions as records: value, span, description, kind, type, match_indices, ...
'%ls --al' | commandline complete --detailed

# One built-in source only: directory, path, glob, command, variable, env-var (last three 0.116+)
'./a' | commandline complete --type directory

# In a completer: path completion for the token, then filter
def "nu-complete nu-scripts" [token: record] {
    $token.text | commandline complete --type path | where $it ends-with '.nu'
}
```

- `--type` completes the whole piped string as one token, so pipe `$token.text`, not the line.
- `--type env-var` takes the bare name (`MYENV`), not `$env.MYENV`.
- A wrong `--type` fails with `expected one of directory, path, glob, command, variable, env-var`.
- `--input` cannot be combined with `--detailed` or `--type` ("Incompatible parameters").
- With `--detailed`, a suggestion with no specific type carries `type: null` (0.115.1+).
- A completer's deprecation warnings print when `commandline complete` returns — a quick way to find old-style completers in a module.

`use`, `overlay use`, `export use`, `source-env`, `hide-env`, `attr complete` and `which` complete like every other builtin (0.115+), and module items complete with nothing typed yet:

```nu
'use std/formats ' | commandline complete
# => ['"from ndjson"' '"from jsonl"' '"to ndjson"' ...] — a name with a space comes back quoted, ready to insert
```

Don't hand-write a completer to paper over a missing builtin completion here.

## Persistent Menus (Nu 0.116+)

```nu
$env.config.completions.persistent_menus = true
```

With `true`, an open completion menu stays open while you edit: Backspace re-runs the completion and refilters the menu instead of closing it.
Default `false`.

## For Extern Commands

```nu
export extern "git push" [
    remote?: string@"nu-complete git remotes"
    refspec?: string@"nu-complete git branches"
    --force (-f)
    --set-upstream (-u)
]
```

## Never Declare `--help`

Nushell intercepts `--help` and `-h` for anything carrying a signature — an `extern` included — and prints the signature instead of running the binary.
Declaring the flag therefore breaks the tool's own help, silently:

```nu
# ❌ WRONG — `fd --help` now prints `Usage: > fd {flags} (pattern) ...(args)`
export extern main [ pattern?: string --help(-h) --hidden ]

# ✅ CORRECT — leave it out; nushell passes --help and -h through to the binary
export extern main [ pattern?: string --hidden ]
```

Leave it undeclared even though the tool's own `--help` output lists it.
That listing is exactly the trap: the natural move is to declare every flag you see, and three separate agents writing three separate completion files each reproduced this bug independently, breaking `hx`, `fd`, `chafa`, `zellij`, `lazygit`, `rg`, `vd` and `delta`.

## Module Naming Rule

When the file is named after the command (e.g., `chafa.nu`), the extern **must** be named `main`:

```nu
# File: chafa.nu
# Import: use chafa.nu

# ❌ WRONG - "Can't export known external named same as the module"
export extern chafa [...]

# ✅ CORRECT - `main` becomes the module's default command
export extern main [...]
```

## Best Practices

1. **Prefer inline** `@[a b c]` for small static lists
2. **Use const** `@$var` for reusable static lists
3. **Naming**: Use `nu-complete <command> <what>` pattern for functions
4. **Module scope**: Define completers as private, export only the command
5. **Dynamic data**: Shell out to get live values (`git remote | lines`)
6. **Declare only the inputs you read** — `[token: record]` for the typed word, `[place: record]` for the command around it; don't call `commandline` inside a completer, read `buffer`
7. **Suppress completions**: Return `[]` for args accepting any value
8. **File fallback**: Return `null` to let file completion answer; `fallback: true` to show both
9. **Test from a script**: `'<line>' | commandline complete` runs your completer, `--input` shows what it receives
