---
name: nushell-style
description: This skill should be used when writing, editing, reviewing, or debugging Nushell (.nu) files. Covers opinionated pipeline composition, command choices (where vs filter, match vs if/else, get --optional), formatting conventions (Topiary), type signatures, module structure, testing with nutest (unit tests, snapshot tests, @example attributes, coverage), NUON data format, the fancy-regex flavor behind =~ and --regex flags, toolkit.nu patterns, nu --ide-check debugging, the Nushell MCP server, and migration guide for updating scripts across Nushell versions (0.100–0.114: breaking changes, renamed commands, new idioms). Relevant when the user says "write nushell code," "review my .nu file," "nushell style," "nushell best practices," "format nushell," "nushell pipeline," "nutest," "NUON," "nushell regex," "lookahead," "lookbehind," "backreference," "nu --ide-check," "nushell MCP," "update nushell script," "nushell breaking changes," or "nushell migration."
---

# Nushell Code Style Guide

## Contents

| File | Topic |
|------|-------|
| **This file** | Quick reference tables, do/don't checklists |
| [patterns.md](references/patterns.md) | Pipeline composition, command examples, code structure |
| [formatting.md](references/formatting.md) | Topiary conventions, spacing, declarations |
| [debugging.md](references/debugging.md) | `--ide-check` for agents, diagnostic parsing |
| [regex.md](references/regex.md) | fancy-regex flavor — lookaround, backrefs, where it applies |
| [nuon.md](references/nuon.md) | NUON format, data serialization, config files |
| [testing.md](references/testing.md) | nutest framework, snapshots, coverage |
| [toolkit.md](references/toolkit.md) | toolkit.nu, repo utilities, commit conventions |
| [mcp.md](references/mcp.md) | Nushell as MCP server (`nu --mcp`), tools, persistent state |
| [migration.md](references/migration.md) | Breaking changes, renamed commands, new idioms (0.100 → 0.114) |
| [enhancements.md](references/enhancements.md) | New features to improve existing scripts (0.100 → 0.114) |

---

## Agent Tip: Syntax Checking

When you finish writing or editing a `.nu` file, check it:

```nushell
dotnu diagnose file.nu
```

It filters `nu --ide-check` output to real diagnostics and resolves byte spans to line numbers with source context — see [debugging.md](references/debugging.md). Without dotnu, the raw fallback is:

```bash
nu --ide-check 10 file.nu | nu --stdin -c 'lines | each { from json } | where type == "diagnostic"'
```

## Agent Tip: `!=` and `!~` in Bash

The Bash tool escapes `!` → `\!`, breaking `!=` and `!~` in `nu -c`. Use a heredoc or temp file instead. See [testing.md](references/testing.md) for workarounds.

## Agent Tip: Literal `(` in Interpolated Strings

`\(` is an escape **only** in double-quoted interpolation `$"..."`. In `$'...'` the backslash is literal and `(` still starts a subexpression — parens cannot be escaped there at all.

```nushell
$"($header), changed \(trailing whitespace only\)"   # ✓ → H, changed (trailing whitespace only)
$'($header), changed \(trailing whitespace only\)'   # ✗ tries to run `trailing` as a command
```

If the string needs both interpolation and literal parens, use `$"..."`.

## Agent Tip: Regex Is fancy-regex, Not Rust `regex`

`=~`, `!~`, `find --regex`, `parse --regex`, `split * --regex` and `str replace --regex` all run on [`fancy-regex`](https://docs.rs/fancy-regex). Lookahead, lookbehind (including variable-length), backreferences, atomic groups and recursion **all work** — don't fall back to a multi-step pipeline because "Rust regex has no lookaround".

```nushell
$lines | where $it =~ '^(?!\s*#)'                 # ✓ drop comment lines, no `not (...)`
'a:b:c' | str replace --regex '(?<=a:)b' 'B'      # ✓ => a:B:c
```

The one exception is `idx search --regex`, which uses the ripgrep engine and silently matches nothing for those constructs. See [regex.md](references/regex.md).

---

## Conciseness for Advanced Users

Write code that an experienced nushell user can quickly apprehend. Leverage implicit features:

| Verbose | Concise | Why |
|---------|---------|-----|
| `update field {\|row\| $row.field \| str uppercase}` | `update field { str uppercase }` | Closure receives field value directly |
| `each {\|x\| $x \| str trim}` | `each { str trim }` | `$in` implicit, pipeline flows |
| `$list \| each { str trim }` | `$list \| str trim` | Many commands accept `list<string>` directly (see below) |
| `where {\|row\| $row.status == "active"}` | `where status == "active"` | `where` has field shorthand |
| `$data \| each { $in \| process }` | `$data \| each { process }` | `$in` passed automatically to first command |

**Principle:** If an advanced user knows how `update`, `each`, `where` work, they shouldn't need to parse redundant variable declarations.

---

## Command Choices

| Task | Preferred | Avoid |
|------|-----------|-------|
| Filtering | `where` | `filter`, `each {if} \| compact` |
| List filtering | `where $it =~ ...` | `where { $in =~ ... }` |
| Parallel with order | `par-each --keep-order` | `par-each` (when order matters) |
| Pattern dispatch | `match` expression | Long `if/else if` chains |
| Record iteration | `items {\|k v\| ...}` | Manual key extraction |
| Table grouping | `group-by ... --to-table` | Manual grouping |
| Line joining | `str join (char nl)` | `to text` (context dependent) |
| Syntax check (human) | `nu -c 'open file.nu \| nu-check'` | `source file.nu` |
| Syntax check (agent) | `nu --ide-check 10 file.nu` | `nu-check` (unstructured) |
| Membership | `in` operator | Multiple `or` conditions |
| Field extraction | `get --optional` | `each {$in.field?} \| compact` |
| Negation | `$x !~ ...` | `not ($x =~ ...)` |
| List element ops | `$list \| str trim` | `$list \| each { str trim }` |
| Flags in code | `save --force` | `save -f` (short flags) |

Always spell Nushell flags out in full: `uniq --count`, `sort-by --reverse`, `parse --regex`, `print --stderr`, `ps --long`. Short flags are for typing at the prompt, not for code someone else reads. External commands keep their own idiom — `git commit -am`, `rg -n` — since their flags are not Nushell's to style. A `-x` after `--` is data, not a flag, and stays as written.

### Skip `each` When Commands Accept `list<string>`

Many commands accept both `string` and `list<string>` input — they operate on each element automatically. Wrapping them in `each` is redundant.

**Heuristic:** Check `input_output` types. If a command lists both `string` and `list<string>` as input, pipe the list directly.

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

**Shape caveat:** `split row` on a list flattens all results into a single list (`['a,b' 'c,d'] | split row ','` → `[a b c d]`), unlike `each { split row ',' }` which keeps one sublist per element. Other `split` commands (`chars`, `words`) keep sublists.

---

## Pipeline Principles

### Leading `|`
Place `|` at the start of continuation lines, indented one level in from the line that opens the pipeline. A top-level pipeline keeps its `|` at column 0; a pipeline on the right of `let x = …` is a nested expression, so its `|` sits 4 spaces in from the `let`. This is what `topiary format --language nu` produces.

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
A new line per `|` is the default. Several `|` on one line are allowed only in two cases:

1. **The stages read as one action.** `| lines | str trim` is "get clean lines", `| uniq --count | sort-by count --reverse` is "rank by frequency". The reader takes them in as a single move, so splitting them adds noise.
2. **A short parenthesised subexpression** — `(open $file | from json)`, `($row_type | wrap row_type)`. These are arguments, not the shape of the pipeline.

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

Judgement, not a counter: `git branch | lines | str trim` stays on one line because fetching and cleaning are one thought. The test is whether a reader must stop and follow each stage separately, not how many `|` there are.

`|` is the **only** operator that continues a line by itself. `++`, `+`, `and`, `or` and the rest are a parse error when the expression spans lines — leading gives ``Command `++` not found``, trailing gives `Incomplete math expression`. Wrap the whole expression in `( … )`, or rewrite it as a pipeline:

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

→ See [patterns.md](references/patterns.md) for detailed examples.

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

`main` is stripped in script mode but **stays** in module mode. `export` is irrelevant in script mode but **required** in module mode.

| How you run | Calls `def "main test"` | `export` needed? |
|---|---|---|
| `nu toolkit.nu test` | ✓ `main` stripped | No |
| `use toolkit.nu; toolkit main test` | ✓ `main` stays | Yes |
| `use toolkit.nu *; main test` | ✓ bare names | Yes |

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

After `use greet.nu`, call it as `greet "world"` — `main` is replaced by the module name. This applies to `def`, `extern`, and `const`.

### A command name is prose, not code

A quoted `def "…"` name may contain spaces, and that is the whole point of the multi-word form. Use **letters, digits, spaces and hyphens** — nothing else. Write what the command does, in words. Never embed a code fragment, a type, a literal or an operator in the name:

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

The name appears twice, and the second time it is a **bare command call inside a block** — so the parser reads every character of it. The apostrophe opens a string that never closes, and **every test in the file** fails with `nu::parser::unexpected_eof` pointing at generated code that names nothing you wrote. The same shape bites any generator: `@example` bodies, `help` tables rendered back into a script, a name passed through `nu -c`.

Measured, so the rule is not a guess. Breaks the whole file: `'` `` ` `` `"` `(` `)` `[` `]` `|` `#`, and an unbalanced `{`. Survives today: a balanced `{a: 1}` and even `$var`, because the parser matches the longest defined command name first. Do not rely on that second list — it is an accident of how the name happens to lex, it says nothing about the next tool that consumes the name, and a `{a: 1}` name is bad naming regardless of whether it parses.

English wants the apostrophe (`the signer's key`, `it's`), so this is a genuine trap and not a rare edge. Rephrase — a possessive always has an `of` form, and a contraction always has a long form.

---

## Quick Reference

### Do

- Omit `$in |` when command body starts with pipeline command
- Start continuation lines with `|`
- Use empty `else { }` for pass-through
- Use `match` for type dispatch
- Use `in` for membership testing
- Use `get --optional` for field extraction
- Use `scan` for stateful transforms
- Use `where` for filtering
- Use `where $it =~ ...` for list filtering
- Combine consecutive `each` closures when operations can be piped
- Define data first, then filter
- Include type signatures: `]: input -> output {`
- Use `@example` attributes (nutest)
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

---

## Formatting Summary

- Run `topiary format <file>` when available — it is the canonical formatter
- Empty blocks: `{ }` with space
- Closures: `{ expr }` with spaces
- Flags: `--flag (-f)` with space (declare a short alias only on explicit user request)
- Records: multi-line, no trailing comma
- Variables: `let x =` (no `$` on left)

→ See [formatting.md](references/formatting.md) for full conventions.
