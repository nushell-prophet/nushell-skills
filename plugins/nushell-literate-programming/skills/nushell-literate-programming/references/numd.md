# numd — executable markdown documents

numd treats a markdown file as a document with embedded, runnable Nushell. `numd run file.md` finds the ```` ```nu ```` / ```` ```nushell ```` fenced blocks, executes them top-to-bottom in one fresh `nu` process, captures each block's output, and writes that output back into the same file. Prose is untouched; code is untouched; only output lines change.

The design goal is **idempotency**: running the same file twice produces zero diff (unless a command is genuinely dynamic — timestamps, `git tag`, network). This turns `git diff` into a regression test for your documentation: re-run the doc after a Nushell upgrade or a module change, and any behavioral drift shows up as a diff.

## Mental model

- `run` = parse file into blocks → build one intermediate `.nu` script → execute it in a separate process → splice captured output back → save.
- Output lines are comments prefixed `# => `. On every run, numd first **strips** all existing `# => ` lines and `output-numd` blocks, then regenerates them. Never hand-write meaningful `# => ` lines — they are volatile. Plain `#` comments survive.
- All blocks in a file share one process: a `let` or `def` from an earlier block is visible in later blocks.
- By default the intermediate script runs with `nu -n` — no user config, env, or plugins — so output is reproducible on any machine. Pass `--use-host-config` when the doc genuinely needs your config.

## Quickstart

```nushell
numd run demo.md --echo    # preview result in terminal, file untouched
numd run demo.md           # execute and update the file in place
numd run demo.md --dry-run # table of blocks that would execute, no execution
```

`numd run` refuses to overwrite a git-tracked file that has uncommitted changes (`--ignore-git-check` to override). Commit first, run, then read the diff — git is the undo button.

## Fence options

Options go after the language in the infostring, comma-separated: ```` ```nu try, new-instance ````. Both `nu` and `nushell` work. An unknown option is a **hard error** — deliberate fail-fast, so a typo in a safety tag like `no-run` stops the run instead of silently executing the block.

| Option | Meaning |
|---|---|
| `no-run` | Don't execute — the block is illustration only |
| `no-output` | Execute, but capture no output (setup blocks) |
| `try` | Wrap in `try {} catch {\|error\| $error}` — for demonstrating errors |
| `new-instance` | Run in a fresh `nu -c` subprocess for nicely formatted error messages — only honored together with `try` (`try, new-instance`); alone it has no effect |
| `separate-block` | Put output in a following ` ```output-numd ` block instead of inline (lines still carry the `# =>` prefix) |
| `run-once` | Execute once, then the fence is rewritten to `no-run` with output frozen — for side effects that must not repeat |

`numd list-fence-options` returns this table at the prompt.

## What the output looks like

Inline (default):

````markdown
```nu
whoami
# => user

2 + 2
# => 4
```
````

Output attaches per command group — groups are split by blank lines inside the block. Assignments (`let`, `mut`, `def`, `use`), statements ending in `;`, and `print` calls produce no `# =>` lines (numd decides via AST whether appending `| print` is safe).

Separate block (`separate-block` option):

````markdown
```nu separate-block
$var1 | path join 'baz' 'bar'
```

Output:

```
# => foo/baz/bar
```
````

## Generate-regions — raw markdown from commands

For content that should be markdown rather than a code block (tables, generated reference sections), hand-write a one-line HTML comment:

```markdown
<!-- numd-gen: [[name value]; [alpha 1] [beta 2]] | to md -->
```

On the next `numd run` it expands into a marker pair with the command's raw stdout between:

```markdown
<!-- numd-gen-start: [[name value]; [alpha 1] [beta 2]] | to md -->
| name | value |
| --- | --- |
| alpha | 1 |
| beta | 2 |
<!-- numd-gen-end -->
```

Every run replaces the region content with fresh output. This is how numd's own README keeps its command reference current: each command section is a region around `use numd; numd doc 'numd run'`, so the docs regenerate from live `scope` data and can never drift from the actual signatures.

## Command reference

### `numd run <file.md>`

| Flag | Effect |
|---|---|
| `--echo` | Print result to stdout, don't save |
| `--dry-run` | Show blocks that would execute |
| `--eval: string` | Nushell code prepended to the intermediate script — styling/config, e.g. `--eval '$env.numd.table-width = 80'` or `--eval (open -r numd_config.nu)` |
| `--print-block-results` | Stream each block's result as it executes (long-running docs) |
| `--save-intermed-script: path` | Keep the generated intermediate `.nu` for debugging |
| `--no-fail-on-error` | Don't abort on block errors (file is never saved on error either way) |
| `--ignore-git-check` | Skip the uncommitted-changes gate |
| `--no-stats` | Suppress the change-stats summary |
| `--use-host-config` | Load host env/config/plugins instead of `nu -n` |

### `numd clear-outputs <file.md>`

Strips all generated output — the inverse of `run`, and reversible, so there is no git gate.

| Flag | Effect |
|---|---|
| `--echo` | Print instead of saving |
| `--strip-markdown` | Emit only the Nushell code — turns a literate doc back into a plain script |
| `--keep-outputs` | Keep inline `# =>` lines (only collapse regions) |
| `--keep-generated` | Keep generate-region content |

### `numd capture start` / `numd capture stop`

Records a live REPL session into markdown by overriding the `display_output` hook — every command you type and its output land in the file as you work.

```nushell
numd capture start exploration.md   # default file: numd_capture.md
# ... explore interactively ...
numd capture stop
```

`--separate-blocks` gives each pipeline its own code block instead of inline `# =>`. The result is a numd document: edit the prose, delete the dead ends, `numd run` it to verify it still reproduces.

### `numd doc <target>`

Renders markdown documentation for a module (all commands) or one command (`numd doc 'numd run'`) from live `scope` data: description, signature, flags, `@example` blocks, input/output types. `--header-level` and `--no-header` control how it nests under hand-written headers. Made to be placed inside a generate-region.

### Parsing helpers

- `numd parse-help` — beautifies `--help` output for embedding in markdown; `--sections ['Usage' 'Flags']` filters, `--record` returns structured data.
- `numd parse-frontmatter <file>` — YAML frontmatter → record with a `content` field; `to md-with-frontmatter` is the inverse.
- `numd parse-md <file>` — full markdown → semantic block table (headers, paragraphs, code blocks with lang/options, lists, quotes) for programmatic doc processing.
- `use numd/plumbing.nu` — the composable pipeline stages (`parse-file`, `strip-outputs`, `execute-blocks`, `to-markdown`, `to-numd-script`) when you need a custom flow.

## Gotchas

- **Shared state**: blocks run in one process. A `def` in block 1 exists in block 10. Good for tutorials, surprising if you expect isolation — and note there is no pure isolation option: `new-instance` only takes effect together with `try`.
- **Working directory** is where `numd run` was invoked; relative paths in blocks resolve against it.
- **Errors abort the save.** If any block errors, the file is left untouched (the error is reported). Use the `try` fence option for blocks that are *supposed* to error.
- **Trailing comment on a block's last line is stripped** before execution — don't end a block with a line whose `#` is not really a comment.
- **The `# =>` capture is width-sensitive**: tables render at `$env.numd.table-width` (default 120). Pin it via `--eval` for stable diffs across terminals.
- **`run-once` is one-shot** — after the first run the fence says `no-run` and the output is frozen; re-running won't refresh it.
