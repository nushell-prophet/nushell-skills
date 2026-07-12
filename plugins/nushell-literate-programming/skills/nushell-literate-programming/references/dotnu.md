# dotnu — scripts that embed their own output, plus module tooling

Where numd makes markdown executable, dotnu goes the other way: a plain `.nu` script carries its own captured output as comments. The file stays a valid, runnable Nushell script whether or not dotnu is installed — the literate layer is pure convention.

## The embed convention

The capture marker is a pipeline ending in `| print $in`. To native Nushell that suffix is an ordinary print; to dotnu it marks "capture this line's output here". The captured output is written below the line as `# => ` comments.

Before:

```nushell
40 + 2 | print $in

[[name type]; [foo file] [bar dir]] | print $in
```

After `dotnu embeds-update file.nu`:

```nushell
40 + 2 | print $in
# => 42

[[name type]; [foo file] [bar dir]] | print $in
# => ╭───┬──────┬──────╮
# => │ # │ name │ type │
# => ├───┼──────┼──────┤
# => │ 0 │ foo  │ file │
# => │ 1 │ bar  │ dir  │
# => ╰───┴──────┴──────╯
```

`embeds-update` strips all existing `# => ` lines first, then re-captures — so stale or hand-edited annotations are always overwritten and the operation is idempotent. Annotations are placed by source-line identity, not execution order.

### The embed command family

| Command | Role |
|---|---|
| `dotnu embeds-update <file.nu>` | Run the script, refresh every `# =>` block. `--echo` prints instead of saving; a piped-in string returns a string |
| `dotnu embeds-remove` | Strip all `# => ` lines (markers stay) |
| `dotnu embed-add` | From the REPL: append the pipeline you just ran, with its output, to a capture file |

`embed-add` reconstructs the command from sqlite history (errors on txt history). It is an `--env` command: `--capture-path` sticks for the session (default file `dotnu-embeds-capture.nu`). Typical REPL beat: you run something interesting, then `| dotnu embed-add --pipe-further` on the same line — the pipeline and its result are appended to the capture file while the data flows on. The capture file accumulates a session's worth of proven pipelines, ready for `embeds-update` refreshes later.

### Rules for reliable embeds

- Keep `| print $in` on **top-level** lines only. A marker inside a `def` or a loop that fires more than once produces more captures than capture points, and dotnu fail-fasts on the mismatch.
- Captures run under `nu -n` in the script's own directory — your interactive `$env` and config are invisible. Output reflects a bare Nushell, which is what makes it reproducible.

## `dotnu expand-code` — pipelines that write code

The inverse of embeds: a `#** <pipeline>` directive line generates real code lines between itself and a `#**end` marker. Re-running refreshes only the generated lines.

```nushell
#** ls *.nu | where name != 'mod.nu' | get name | each { $"export use ($in) *" } | to text
#**end
```

After `dotnu expand-code mod.nu`:

```nushell
#** ls *.nu | where name != 'mod.nu' | get name | each { $"export use ($in) *" } | to text
export use config.nu *
export use greet.nu *
export use history.nu *
#**end
```

The classic use is exactly this one — a `mod.nu` whose re-export list maintains itself. Relative paths in the directive resolve against the file's directory; the pipeline runs with `--no-config-file` so nothing leaks in. Unclosed `#**`, empty pipeline, or stray `#**end` are hard errors.

## `dotnu examples-update` — living `@example` results

Finds every `@example { code } --result <value>` attribute in a file (via AST, so strings and comments can't false-positive), executes each example in a clean `nu -n`, and rewrites the `--result` value in place. A failing example is skipped with a stderr warning — the file is never corrupted. This keeps documentation examples honest the same way numd keeps READMEs honest: run the updater, read the diff.

## `dotnu set-x` — step-through with timings

The `bash set -x` analogue. Splits a script on blank lines and generates `<file>_setx.nu` where each block is echoed (`nu-highlight`ed) before running and timed after:

```nushell
dotnu set-x slow-script.nu     # writes slow-script_setx.nu, pre-fills `source ...` in your prompt
dotnu set-x slow-script.nu --echo   # print the instrumented script instead
```

Each block prints its elapsed time in grey — the quickest way to find which stanza of a script eats the runtime. `--regex` changes the block-splitting pattern.

## Module analysis and surgery

| Command | What it answers |
|---|---|
| `dotnu dependencies ...paths` | Who calls whom — table of `caller, filename_of_caller, callee, step` across module files, AST-based, transitive (`step` = call depth). `--keep-builtins` includes builtins; `--definitions-only` just lists defined commands |
| `dotnu filter-commands-with-no-tests` | Pipe `dependencies` output in → commands no test reaches (a caller counts as a test when its name contains `test` or its file matches `^test.*\.nu$`) |
| `dotnu list-module-exports <path>` | Everything a module file exports, including through `export use` re-exports |
| `dotnu list-module-interface <path>` | The callable surface after `use` — resolves `def main` / `def 'main sub'` naming |
| `dotnu module-commands-code-to-record <path>` | Record of `{command-name: source}` for every def in a module |
| `dotnu extract-module-command <module> <command>` | Pull one command plus its whole custom-command dependency cascade out of a module into a single self-contained, parse-checked script |

Test-coverage audit as a one-liner:

```nushell
glob dotnu/*.nu | append [tests/test_commands.nu toolkit.nu]
| dotnu dependencies ...$in
| dotnu filter-commands-with-no-tests
```

### `extract-module-command --vars` — a debug scaffold

With `--vars` (or `--set-vars {flag: true}`), the target command's parameters become editable `let` bindings between `#dotnu-vars-start` / `#dotnu-vars-end` markers and the body is unwrapped to top level — sourcing the file runs the command's body with those variables in scope, so you can step through a module command as a plain script. With `--output`, your edited values survive re-extraction (`--clear-vars` resets them).

Safety: extraction refuses modules with `export-env` blocks unless `--allow-export-env` (importing a module runs those blocks). Even allowed, `export-env` content is not carried into the extract — env-dependent commands will extract but may break at runtime.

## `dotnu generate-numd` — the bridge to numd

```nushell
open script.nu | dotnu generate-numd | save script.md
```

Splits a script on blank lines and wraps each block in a ```` ```nu ```` fence — a `.nu` file becomes a numd markdown document, ready for prose between the blocks. This is the promotion path: REPL capture → `.nu` script with embeds → markdown article.

## Gotchas

- Default is **save in place** for `embeds-update`, `expand-code`, `examples-update`, `set-x`; use `--echo` (or pipe a string in) to preview. Same discipline as numd: commit first, run, read the diff.
- `embed-add` needs sqlite history and remembers `--capture-path` per session.
- All execution paths use a clean `nu -n` — reproducible, but blind to your config.
- On Windows, CRLF is normalized to LF; output always ends with a single trailing newline.
