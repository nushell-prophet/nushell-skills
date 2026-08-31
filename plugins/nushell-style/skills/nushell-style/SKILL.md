---
name: nushell-style
description: This skill should be used when writing, editing, reviewing, or debugging Nushell (.nu) files. Covers opinionated pipeline composition, command choices (where vs filter, match vs if/else, get --optional), formatting conventions (Topiary), type signatures, module structure, testing with nutest (unit tests, snapshot tests, @example attributes, coverage), NUON data format, the fancy-regex flavor behind =~ and --regex flags, toolkit.nu patterns, nu --ide-check debugging, the Nushell MCP server, and migration guide for updating scripts across Nushell versions (0.100–0.115: breaking changes, renamed commands, new idioms). Relevant when the user says "write nushell code," "review my .nu file," "nushell style," "nushell best practices," "format nushell," "nushell pipeline," "nutest," "NUON," "nushell regex," "lookahead," "lookbehind," "backreference," "nu --ide-check," "nushell MCP," "update nushell script," "nushell breaking changes," or "nushell migration."
---

# Nushell Code Style Guide

## Contents

- **This file** — quick reference lists, do/don't checklists
- `references/patterns.md` — pipeline composition, command examples, code structure, cell-paths as values, error construction
- `references/formatting.md` — Topiary conventions, spacing, declarations
- `references/debugging.md` — `--ide-check` for agents, diagnostic parsing
- `references/regex.md` — fancy-regex flavor: lookaround, backrefs, where it applies
- `references/nuon.md` — NUON format, data serialization, config files
- `references/testing.md` — nutest framework, snapshots, coverage
- `references/toolkit.md` — toolkit.nu, repo utilities, commit conventions
- `references/mcp.md` — Nushell as MCP server (`nu --mcp`), tools, persistent state
- `references/migration.md` — breaking changes, renamed commands, new idioms (0.100 → 0.115)
- `references/enhancements.md` — new features to improve existing scripts (0.100 → 0.115)

---

## Agent Tip: Syntax Checking

When you finish writing or editing a `.nu` file, check it:

```nushell
dotnu diagnose file.nu
```

It filters `nu --ide-check` output to real diagnostics and resolves byte spans to line numbers with source context — see `references/debugging.md`.
Without dotnu, the raw fallback is:

```bash
nu --ide-check 10 file.nu | nu --stdin -c 'lines | each { from json } | where type == "diagnostic"'
```

## Agent Tip: `!=` and `!~` in Bash

The Bash tool escapes `!` → `\!`, breaking `!=` and `!~` in `nu -c`.
Use a heredoc or temp file instead.
See `references/testing.md` for workarounds.

## Agent Tip: Literal `(` in Interpolated Strings

`\(` is an escape **only** in double-quoted interpolation `$"..."`.
In `$'...'` the backslash is literal and `(` still starts a subexpression — parens cannot be escaped there at all.

```nushell
$"($header), changed \(trailing whitespace only\)"   # ✓ → H, changed (trailing whitespace only)
$'($header), changed \(trailing whitespace only\)'   # ✗ tries to run `trailing` as a command
```

If the string needs both interpolation and literal parens, use `$"..."`.

## Agent Tip: Regex Is fancy-regex, Not Rust `regex`

`=~`, `!~`, `find --regex`, `parse --regex`, `split * --regex` and `str replace --regex` all run on [`fancy-regex`](https://docs.rs/fancy-regex).
Lookahead, lookbehind (including variable-length), backreferences, atomic groups and recursion **all work** — don't fall back to a multi-step pipeline because "Rust regex has no lookaround".

```nushell
$lines | where $it =~ '^(?!\s*#)'                 # ✓ drop comment lines, no `not (...)`
'a:b:c' | str replace --regex '(?<=a:)b' 'B'      # ✓ => a:B:c
```

The one exception is `idx search --regex`, which uses the ripgrep engine and silently matches nothing for those constructs.
See `references/regex.md`.

## Agent Tip: `open file.md` Returns Structured Data, Not Text

Since v0.112 `open` runs `from md` on a `.md` path, so you get a table of `element`/`content` rows instead of the file's text.
Use `--raw` whenever you want the text — it yields a byte stream, which `lines`, `str replace` and `save` all accept.

```nushell
open README.md                       # table<element: string, content: string, content_span: record<...>>
open README.md --raw                 # byte stream — the actual text
open README.md --raw | from md --verbose   # full AST (the pre-0.113 shape)
```

Two failure modes, and only one of them is loud:

```nushell
open x.md | str replace 'a' 'b'      # ✗ Error: Input type not supported.
open x.md | save y.md                # ✗ silent — writes the parsed AST as a markdown table
```

`hide 'from md'` turns the conversion off for the rest of the session.

---

## Conciseness for Advanced Users

Write code that an experienced nushell user can quickly apprehend.
Leverage implicit features:

- `update field {|row| $row.field | str uppercase}` → `update field { str uppercase }` — closure receives field value directly
- `each {|x| $x | str trim}` → `each { str trim }` — `$in` implicit, pipeline flows
- `$list | each { str trim }` → `$list | str trim` — many commands accept `list<string>` directly (see below)
- `where {|row| $row.status == "active"}` → `where status == "active"` — `where` has field shorthand
- `$data | each { $in | process }` → `$data | each { process }` — `$in` passed automatically to first command

**Principle:** If an advanced user knows how `update`, `each`, `where` work, they shouldn't need to parse redundant variable declarations.

---

## Command Choices

- Filtering — prefer `where`, avoid `filter`, `each {if} | compact`
- List filtering — prefer `where $it =~ ...`, avoid `where { $in =~ ... }`
- Parallel with order — prefer `par-each --keep-order`, avoid `par-each` (when order matters)
- Pattern dispatch — prefer `match` expression, avoid long `if/else if` chains
- Record iteration — prefer `items {|k v| ...}`, avoid manual key extraction
- Table grouping — prefer `group-by ... --to-table`, avoid manual grouping
- Line joining — prefer `str join (char nl)`, avoid `to text` (context dependent)
- Syntax check (human) — prefer `nu -c 'open file.nu | nu-check'`, avoid `source file.nu`
- Syntax check (agent) — prefer `nu --ide-check 10 file.nu`, avoid `nu-check` (unstructured)
- Membership — prefer `in` operator, avoid multiple `or` conditions
- Field extraction — prefer `get --optional`, avoid `each {$in.field?} | compact`
- Negation — prefer `$x !~ ...`, avoid `not ($x =~ ...)`
- List element ops — prefer `$list | str trim`, avoid `$list | each { str trim }`
- Flags in code — prefer `save --force`, avoid `save -f` (short flags)

Always spell Nushell flags out in full: `uniq --count`, `sort-by --reverse`, `parse --regex`, `print --stderr`, `ps --long`.
Short flags are for typing at the prompt, not for code someone else reads.
External commands keep their own idiom — `git commit -am`, `rg -n` — since their flags are not Nushell's to style.
A `-x` after `--` is data, not a flag, and stays as written.

### Skip `each` When Commands Accept `list<string>`

Many commands accept both `string` and `list<string>` input — they operate on each element automatically.
Wrapping them in `each` is redundant.

**Heuristic:** Check `input_output` types.
If a command lists both `string` and `list<string>` as input, pipe the list directly.

```nushell
# Check a command's accepted input types (help <cmd> returns rendered text, not data)
help commands | where name == 'str trim' | get input_output.0
# => [[input, output]; [string, string], [list<string>, list<string>], ...]
```

Common command families that accept `list<string>` directly: `str` (19 commands), `path` (9), `split` (4), `into` (4), `ansi` (3), `url` (2), `fill`.

```nushell
# Preferred                          # Avoid
$list | str trim                     # $list | each { str trim }
$list | path expand                  # $list | each { path expand }
$list | ansi strip                   # $list | each { ansi strip }
$list | str replace 'a' 'b'         # $list | each { str replace 'a' 'b' }
$list | url encode                   # $list | each { url encode }
```

`each` IS needed when the command does not accept `list` input, or when the closure does more than a single command call.

**Shape caveat:** `split row` on a list flattens all results into a single list (`['a,b' 'c,d'] | split row ','` → `[a b c d]`), unlike `each { split row ',' }` which keeps one sublist per element.
Other `split` commands (`chars`, `words`) keep sublists.

---

## Pipeline Principles

### Leading `|`
Place `|` at the start of continuation lines, indented one level in from the line that opens the pipeline.
A top-level pipeline keeps its `|` at column 0; a pipeline on the right of `let x = …` is a nested expression, so its `|` sits 4 spaces in from the `let`.
This is what `topiary format --language nu` produces.

```nushell
# Top level — column 0
$file_lines | wrap line
| merge ($row_type | wrap row_type)
| group-by block_index --to-table

# Right-hand side of `let` — indented one level
let row_type = $file_lines
    | each { str trim --right }
    | scan --fold 'text' {|curr prev| $curr }
```

### One Step Per Line
A new line per `|` is the default.
Several `|` on one line are allowed only in two cases:

1. **The stages read as one action.** `| lines | str trim` is "get clean lines", `| uniq --count | sort-by count --reverse` is "rank by frequency".
   The reader takes them in as a single move, so splitting them adds noise.
2. **A short parenthesised subexpression** — `(open $file | from json)`, `($row_type | wrap row_type)`.
   These are arguments, not the shape of the pipeline.

Everywhere else, when each stage is a separate transformation the reader has to follow one at a time, give it its own line.

```nushell
# Preferred — one transformation per line, groups kept intact
history --long
| where start_timestamp > ((date now) - 1wk)
| get command
| parse --regex '^(?<head>[\w-]+)' | get head
| uniq --count | sort-by count --reverse

# Avoid — five distinct steps hidden in one line
history --long | where start_timestamp > ((date now) - 1wk) | get command | uniq --count | sort-by count --reverse
```

Judgement, not a counter: `git branch | lines | str trim` stays on one line because fetching and cleaning are one thought.
The test is whether a reader must stop and follow each stage separately, not how many `|` there are.

`|` is the **only** operator that continues a line by itself.
`++`, `+`, `and`, `or` and the rest are a parse error when the expression spans lines — leading gives ``Command `++` not found``, trailing gives `Incomplete math expression`.
Wrap the whole expression in `( … )`, or rewrite it as a pipeline:

```nushell
# Fails to parse
let a = [x y]
    ++ (if $flag { [z] } else { [] })

# Preferred — a pipeline
let a = [x y]
    | append (if $flag { [z] } else { [] })

# Also fine — parens make the line break legal
let a = (
    [x y]
    ++ (if $flag { [z] } else { [] })
)
```

### Omit `$in |`
When body starts with pipeline command (`each`, `where`, `select`), input flows automatically.

### Empty `{ }` Pass-Through
Use empty `{ }` for the branch that should pass through unchanged:
- `| if $cond { transform } else { }` — transform when true, pass through when false
- `| if $cond { } else { transform }` — pass through when true, transform when false

### Stateful Transforms
Use `scan` for sequences with state: `use std/iter scan`

→ See `references/patterns.md` for detailed examples.

---

## Script CLI Pattern

For toolkit-style scripts with subcommands (like `nu toolkit.nu test`):

```nushell
# toolkit.nu
export def main [] { }  # Entry point (required, even if empty)

export def 'main test' [--json] {
    # nu toolkit.nu test
}

export def 'main build' [] {
    # nu toolkit.nu build
}
```

**Key points:**
- `def main []` — entry point when running `nu script.nu`
- `def 'main subcommand' []` — defines `nu script.nu subcommand`
- Must define `main` for subcommands to be accessible
- Use `export def` if script is also used as a module

### Script mode vs module mode

`main` is stripped in script mode but **stays** in module mode.
`export` is irrelevant in script mode but **required** in module mode.

Each of these calls `def "main test"`:

- `nu toolkit.nu test` — `main` stripped; `export` needed: no
- `use toolkit.nu; toolkit main test` — `main` stays; `export` needed: yes
- `use toolkit.nu *; main test` — bare names; `export` needed: yes

**⚠ Common agent mistake** — using `use` (module mode) but calling with script-mode syntax:

```nushell
# WRONG: script-mode syntax after module-mode import
use toolkit.nu
toolkit test              # Error: extra positional argument

# CORRECT: include `main` in the command path
use toolkit.nu
toolkit main test         # ✓

# OR: just use script mode
# nu toolkit.nu test      # ✓
```

When in doubt, prefer script mode (`nu script.nu subcommand`) — it's simpler and avoids the `main` path issue.

→ See [Nushell Scripts docs](https://www.nushell.sh/book/scripts.html#subcommands)

### Module Naming Rule

When a file is named after the command (e.g., `greet.nu`), the command **must** be named `main`, not the file name:

```nushell
# File: greet.nu

# WRONG — "Can't export ... named same as the module"
export def greet [name: string] { $"Hello ($name)" }

# CORRECT — `main` becomes the module's default command
export def main [name: string] { $"Hello ($name)" }
```

After `use greet.nu`, call it as `greet "world"` — `main` is replaced by the module name.
This applies to `def`, `extern`, and `const`.

### A command name is prose, not code

A quoted `def "…"` name may contain spaces, and that is the whole point of the multi-word form.
Use **letters, digits, spaces and hyphens** — nothing else.
Write what the command does, in words.
Never embed a code fragment, a type, a literal or an operator in the name:

```nushell
# WRONG — a code fragment in the name; says nothing a reader could not get from the body
def "a record {a: 1} round-trips" [] { ... }

# WRONG — the apostrophe English wants here takes the whole file down (see below)
def "the signer's endorsement" [] { ... }

# CORRECT — prose, and it survives being re-parsed
def "a single-field record round-trips" [] { ... }
def "the endorsement of the signer" [] { ... }
```

Why this is not merely a style preference: a command name is *data that other tools put back into source code*. nutest builds its suite descriptor by interpolating every test name into generated Nushell:

```nushell
{ name: "the signer's endorsement", type: "test", execute: { the signer's endorsement } }
```

The name appears twice, and the second time it is a **bare command call inside a block** — so the parser reads every character of it.
The apostrophe opens a string that never closes, and **every test in the file** fails with `nu::parser::unexpected_eof` pointing at generated code that names nothing you wrote.
The same shape bites any generator: `@example` bodies, `help` tables rendered back into a script, a name passed through `nu -c`.

Measured, so the rule is not a guess.
Breaks the whole file: `'` `` ` `` `"` `(` `)` `[` `]` `|` `#`, and an unbalanced `{`.
Survives today: a balanced `{a: 1}` and even `$var`, because the parser matches the longest defined command name first.
Do not rely on that second list — it is an accident of how the name happens to lex, it says nothing about the next tool that consumes the name, and a `{a: 1}` name is bad naming regardless of whether it parses.

English wants the apostrophe (`the signer's key`, `it's`), so this is a genuine trap and not a rare edge.
Rephrase — a possessive always has an `of` form, and a contraction always has a long form.

Separate rule, same place it bites: since 0.115 a command name can never *be* a parser keyword.
`def def`, `def if`, `def let` fail with `nu::parser::name_is_keyword`, and that covers module exports and `use *` too.
Ordinary builtins stay shadowable — `def ls` still works, and `%ls` reaches the real one.

---

## Quick Reference

### Do

- Omit `$in |` when command body starts with pipeline command
- Start continuation lines with `|`
- Use empty `else { }` for pass-through
- Use `match` for type dispatch
- Use `in` for membership testing
- Use `get --optional` for field extraction
- Build a `get`/`update` path as a cell-path value (`$.a.b`, `into cell-path`), not an interpolated string (see `references/patterns.md`)
- Use `scan` for stateful transforms
- Use `where` for filtering
- Use `where $it =~ ...` for list filtering
- Combine consecutive `each` closures when operations can be piped
- Use `each --keep-empty` when the result is zipped or merged back against the input
- Dispatch on input type with `peek | metadata access` where a real stream is typed and the branch turns on a bare type name — `peek` reports `list` for a table and `custom` for every plugin value, so check what the branches separate first (see `references/patterns.md`)
- Define data first, then filter
- Include type signatures: `]: input -> output {`
- Document non-obvious flags/parameters with a trailing `# comment` — it becomes their `help` description (see `references/formatting.md`)
- Use `@example` attributes (nutest)
- Add `@category` to commands exported through `mod.nu`
- Leave `@search-terms` off unless a word passes all three tests in `references/patterns.md` — zero terms is the normal state
- Give a module its own `example` command once its subcommands compose into pipelines a user types in the REPL — built from the `@example` attributes it already carries, it pastes one into their command line; not worth it for a single command or a script-only library (see `references/patterns.md`)
- Give `error make` a `label` with `span: (metadata $param).span`, plus `help:` for the fix — only in a command the user calls directly, and drop `--unspanned` when you add one (see `references/patterns.md`)
- Call a shadowed builtin through the `%` sigil (`%update`, `%str contains`) at the call site
- Use `const` for static data
- Keep custom commands focused
- Export ALL commands from implementation files (enables testing helpers)
- Control public API via `mod.nu` re-exports (not by removing exports)
- Use `par-each --keep-order` for parallel with deterministic output

### Don't

- Start command bodies with `$in |` when a pipeline command follows
- Use spread operator `...` with conditionals (use data-first + `where`)
- Wrap external commands in unnecessary parentheses
- Over-extract helpers for one-time use
- Create wrapper commands that just call an existing command
- Use verbose names for local variables
- Break the pipeline flow unnecessarily
- Remove existing comments (preserve user's context)
- Remove `export` from helpers to "make them private" (use mod.nu instead)
- Name a command the same as its file (use `main` instead — see Module Naming Rule)
- Use short flags in code (`save -f`, `open -r`) — write the long form (`save --force`, `open --raw`); short flags are for interactive typing
- Write `\(` inside `$'...'` — single-quote interpolation has no escapes; literal parens need `$"..."` (see Agent Tip above)
- Declare short flag aliases (`--force (-f)`) in command signatures unless the user explicitly asks for them
- Fill a `@search-terms` quota — a fixed count per command means synonyms of its own name, which `help --find` already matches through the name and description
- Rewrite a `describe` as `peek` when the value is already in hand — a named parameter, a `let`-bound variable, a record field. It spares no stream, which is the idiom's whole purpose, and only lengthens the line
- Reach for dynamic `%$var` dispatch when the command set is known as you write — it blinds `dotnu diagnose`, changes how bare cell-path arguments parse, and turns any name from config or `$env` into an arbitrary-builtin call (see `references/enhancements.md`)

---

## Formatting Summary

- Run `topiary format <file>` when available — it is the canonical formatter
- Empty blocks: `{ }` with space
- Closures: `{ expr }` with spaces
- Flags: `--flag (-f)` with space (declare a short alias only on explicit user request)
- Records: multi-line, no trailing comma
- Variables: `let x =` (no `$` on left)

→ See `references/formatting.md` for full conventions.
