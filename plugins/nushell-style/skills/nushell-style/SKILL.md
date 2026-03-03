---
name: nushell-style
description: Load this skill when editing, writing, or reviewing any .nu file. Provides opinionated Nushell patterns, pipeline composition, command choices, and formatting conventions.
---

# Nushell Code Style Guide

## Contents

| File | Topic |
|------|-------|
| **This file** | Quick reference tables, do/don't checklists |
| [patterns.md](references/patterns.md) | Pipeline composition, command examples, code structure |
| [formatting.md](references/formatting.md) | Topiary conventions, spacing, declarations |
| [debugging.md](references/debugging.md) | `--ide-check` for agents, diagnostic parsing |
| [nuon.md](references/nuon.md) | NUON format, data serialization, config files |
| [testing.md](references/testing.md) | nutest framework, snapshots, coverage |
| [toolkit.md](references/toolkit.md) | toolkit.nu, repo utilities, commit conventions |

---

## Agent Tip: Syntax Checking

```bash
nu --ide-check 10 file.nu | nu --stdin -c 'lines | each { from json } | where type == "diagnostic"'
```

With line numbers and source context (replace `FILE` with path):

```bash
nu -c 'let c = open --raw FILE; let l = $c | lines; nu --ide-check 10 FILE | lines | each { from json } | where type == "diagnostic" | each {|d| let n = ($c | str substring 0..<$d.span.start | split row "\n" | length); {line: $n, message: $d.message, source: ($l | get ($n - 1) | str trim), span: ($c | str substring $d.span.start..<$d.span.end)}} | uniq'
```

Both run from bash. See [debugging.md](references/debugging.md) for the full nushell command.

## Agent Tip: `!=` and `!~` in Bash

**⚠ `nu -c` breaks `!=` and `!~`** — the Bash tool escapes `!` → `\!` regardless of quoting. Use a heredoc wrapper:

```bash
nu -c "$(cat << 'EOF'
if $x != null { print "yes" }
$data | where name !~ "skip"
EOF
)"
```

Or use a temp file for longer code. See [testing.md](references/testing.md) for details.

---

## Conciseness for Advanced Users

Write code that an experienced nushell user can quickly apprehend. Leverage implicit features:

| Verbose | Concise | Why |
|---------|---------|-----|
| `update field {\|row\| $row.field \| str upcase}` | `update field { str upcase }` | Closure receives field value directly |
| `each {\|x\| $x \| str trim}` | `each { str trim }` | `$in` implicit, pipeline flows |
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

---

## Pipeline Principles

### Leading `|`
Place `|` at start of continuation lines, aligned with `let`.

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

---

## Formatting Summary

- Run `topiary format <file>` when available — it is the canonical formatter
- Empty blocks: `{ }` with space
- Closures: `{ expr }` with spaces
- Flags: `--flag (-f)` with space
- Records: multi-line, no trailing comma
- Variables: `let x =` (no `$` on left)

→ See [formatting.md](references/formatting.md) for full conventions.
