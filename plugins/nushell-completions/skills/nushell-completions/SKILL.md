---
name: nushell-completions
description: This skill should be used when generating Nushell custom completions, writing completer functions, adding tab-completion to extern commands, using string@completer annotations, inline @[...] completion lists, or the @complete attribute. Relevant when the user asks to "add completions," "write a completer," "create an extern with tab completion," or "build context-aware argument suggestions" in Nushell.
---

# Nushell Custom Completions

Generate completions for Nushell commands following these patterns.

## Quick Reference

- `string@[a b c]` — inline static list (0.108+)
- `string@$const_list` — const variable (0.108+)
- `string@completer` — custom completer function (all versions)
- `@complete fn` — command-wide completer (0.108+)
- `commandline complete` — reuse nushell's own suggestions (0.114+)

## Inline Completions (Nu 0.108+)

Simplest approach for static options:

```nu
# Inline list directly in signature
def go [direction: string@[left up right down]] { $direction }

# Using const variable
const directions = [left up right down]
def go [direction: string@$directions] { $direction }
```

Builtins use the same pattern — since 0.115 the unit argument of `format duration` and `format filesize` completes from such a list.

## Command-Wide Completers (Nu 0.108+)

Use `@complete` attribute for all arguments of a command:

```nu
# Use the global external completer
@complete external
def --wrapped jc [...args] { ^jc ...$args | from json }

# Use a specific completer for all args
def carapace-completer [spans: list<string>] {
    carapace $spans.0 nushell ...$spans | from json
}

@complete carapace-completer
def --env get-env [name] { $env | get $name }

# For extern wrappers
@complete fish-completer
extern git []
```

## Custom Completer Functions

For dynamic completions:

```nu
# Simple completer
def "nu-complete git remotes" [] {
    git remote | lines
}

# With descriptions
def "nu-complete branches" [] {
    git branch --format='%(refname:short)|%(subject)'
    | lines
    | split column '|' value description
}

# Context-aware (uses previous arguments)
def "nu-complete git branches" [context: string] {
    # split row ' ', not split words — split words breaks on hyphens (my-cmd → [my, cmd])
    let remote = $context | split row ' ' | get 1?
    if $remote != null {
        git branch --remotes
        | lines | str trim
        | where { str starts-with $remote }
    } else {
        git branch | lines | str trim
    }
}

# Attach to command
def my-cmd [
    remote: string@"nu-complete git remotes"
    branch: string@"nu-complete git branches"
] { }
```

## Completion Caching (Nu 0.115+)

Completion results now survive across prompts; before 0.115 they were discarded at every new prompt.
`$env.config.completions.cache_size` caps how many entries are kept (default `100`, least-recently-used eviction), and `0` turns the cache off.

Custom completers are cached too, so a slow completer stops re-running on every prompt for the same typed text.
Two things follow for a completer that shells out for live data:

- An entry is dropped when the completion-relevant environment changes — nushell fingerprints the cwd, the cwd's modification time, `$env.PATH`, and the number of known declarations.
  Data that changes without touching any of those (a new git branch, say) can be served stale until something else invalidates the entry.
- While iterating on a completer, set `$env.config.completions.cache_size = 0` so you always see what the current code returns.

## Reusing Built-in Completions (Nu 0.114+)

`commandline complete` returns the suggestions nushell itself would offer for a given string (cursor assumed at the end).
Use it inside completers to wrap built-in path/flag completion instead of reimplementing it:

```nu
# Directory suggestions for a partial path
'./a' | commandline complete --type directory   # --type: directory | glob | path

# All flags of a command, as records with descriptions
'%ls -' | commandline complete --detailed

# In a completer: complete paths, then filter
def "nu-complete nu-scripts" [context: string] {
    $context | split row ' ' | last
    | commandline complete --type path
    | where $it ends-with '.nu'
}
```

Without `--detailed` the output is `list<string>`; with it, records carrying `value` plus whatever nushell knows about the suggestion — `span`, `description`, `kind`, `type`, and `style` when one is set.
Without piped input it completes the current commandline buffer.

Two 0.115 fixes worth knowing:

- `--type` is now validated: a wrong value fails with `expected type "directory", "path", or "glob"`.
  An out-of-range cursor no longer panics either.
- `use`, `overlay use`, `export use`, `source-env`, `hide-env`, `attr complete` and `which` go through the same dispatch as every other builtin, so they complete consistently — and `commandline complete` returns their suggestions too.
  Module items now complete with nothing typed to match against:

```nu
'use std/formats ' | commandline complete
# => ['"from ndjson"' '"from jsonl"' '"to ndjson"' ...] — a name with a space comes back quoted, ready to insert
```

Don't hand-write a completer to paper over a missing builtin completion here — on 0.115 they work.

## Completer Patterns

- **Inline list** — returns `@[a b c]`, for static options (simplest)
- **Simple list** — returns `list<string>`, for dynamic options
- **With descriptions** — returns `list<record<value, description>>`, for options needing explanation
- **With options** — returns `record<completions, options>`, for custom sorting/matching
- **Context-aware** — accepts a `context: string` param, for completions that depend on previous args
- **Null return** — returns `null`, to fall back to file completions

## With Matching Options

```nu
def "nu-complete commands" [] {
    {
        options: {
            case_sensitive: false
            completion_algorithm: fuzzy
            sort: false  # preserve original order
        }
        completions: [
            {value: "build" description: "Build the project"}
            {value: "test" description: "Run tests"}
        ]
    }
}
```

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

## Completer Signature Options

```nu
def completer [] { }                              # simple
def completer [context: string] { }               # with command line
def completer [context: string pos: int] { }      # with cursor position
def completer [spans: list<string>] { }           # for @complete (list of args)
```

## Best Practices

1. **Prefer inline** `@[a b c]` for small static lists
2. **Use const** `@$var` for reusable static lists
3. **Naming**: Use `nu-complete <command> <what>` pattern for functions
4. **Module scope**: Define completers as private, export only the command
5. **Dynamic data**: Shell out to get live values (`git remote | lines`)
6. **Suppress completions**: Return `[ ]` for args accepting any value
7. **File fallback**: Return `null` to use Nushell's file completions

## Record Fields

- `value` — `string`, the completion text
- `description` — `string?`, shown in menu
- `style` — `string`/`record?`, the color: `"red"`, `{fg: green, bg: black, attr: b}`

## Options Record

- `sort` — `true`/`false`, default `true`
- `case_sensitive` — `true`/`false`, default from config
- `completion_algorithm` — `prefix`/`substring`/`fuzzy`, default from config
