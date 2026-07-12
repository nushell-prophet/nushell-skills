# Companions — nu-goodies and claude-nu in the literate loop

numd and dotnu are the engines; nu-goodies and claude-nu supply the everyday on-ramps: capturing what just happened in the terminal, and turning AI sessions into documents.

## nu-goodies — capture and presentation helpers

Load with `use nu-goodies *`. The commands below all feed the same `# =>` annotation convention that numd and dotnu read and write — nu-goodies is a *producer* of literate snippets.

### `example` — share the command you just ran

Takes the last piped command, renders its output, comments every output line with `# =>`, wraps the command in `nu -c '...'`, and copies the whole thing to the clipboard:

```nushell
ls nu-goodies | first 2 | reject modified | example
```

Clipboard now holds a runnable, self-documenting snippet — paste it into a chat, an issue, or a numd document. Flags: `--bare` (raw nushell, no `nu -c` wrap — the right form for pasting into a numd block), `--no-comment`, `--no-copy`, `--abbreviated N`.

### `copy-out` — lift command + output from Zellij scrollback

When the interesting thing already happened and you didn't pipe it anywhere:

```nushell
copy-out       # last command + its output, output commented with '# => '
copy-out 3     # from 3rd-to-last through the last command
copy-out 3 1   # 3rd-to-last and last, separately
```

`--cwd` prepends a comment line with the working directory; `--echo` returns instead of copying. This is REPL archaeology: the terminal itself becomes the source of a literate snippet. `delete-prompts` is the cleanup twin — removes the last N prompts from scrollback before a screenshot.

### `hist-to-script` — a session's history as a script

Dumps the commands of the current session (or directory) into a `.nu` file — the rawest form of "what did I just do", ready to be pruned, annotated with `| print $in` markers, and promoted through `dotnu embeds-update`.

### Presentation and exploration

| Command | Literate use |
|---|---|
| `cprint` | Colorful, wrapped, `*highlighted*` prose inside scripts and demos |
| `nu-format` | Topiary-format a snippet (breaks before pipes) before it goes into a doc |
| `number-format` / `number-col-format` | Human-readable numbers in tables destined for documents |
| `format profile` | `debug profile` output as an indented tree with duration bars |
| `L` | Page a wide table through `less`/`bat` with `table -e` rendering |
| `bar` | Inline Unicode bars — `bar 0.71` → `███▌` — for tables in reports |
| `tile-right` / `tile-left` / `tile-up` / `tile-down` | Compose two text blocks into one figure, ANSI-aware |
| `rgv` | ripgrep as a table of `path:line:col` links |
| `fzf-preview` | Pick from any piped table with a bat preview; `--content` previews cell values |
| `in-vd` / `in-hx` / `in-fx` | Hand a table to VisiData / Helix / fx and round-trip the edits |
| `ansi-to-png`, `zellij-to-png`, `wez-to-png` / `wez-to-gif` | Render colored terminal output to images for docs |

## claude-nu — sessions as documents, Claude as a pipeline stage

Load with `use claude-nu`. Claude Code stores every session as JSONL under `~/.claude/projects/`; claude-nu parses that into tables you can `where`/`sort-by` like anything else.

### Reading sessions

```nushell
claude-nu projects                    # all projects, most recent first; rows pipe into sessions
claude-nu sessions                    # this project's sessions: summary, timestamps, user messages...
claude-nu sessions --last --columns token_usage
claude-nu messages 'regex'            # user messages matching a regex
claude-nu -f 'monorepo' --all-projects   # search user messages across every project
```

Useful columns beyond the defaults (`--columns` or `--all-columns`): `bash_commands`, `skill_invocations`, `tool_errors`, `git_branch`, `token_usage`, `edited_files`, `read_files`.

### Exporting sessions to markdown

The flow that turns a working conversation into a permanent document:

```nushell
claude-nu sessions | sort-by last_timestamp | last | claude-nu export-session | claude-nu save-markdown
```

`export-session` renders the dialogue as markdown with YAML frontmatter (`date`, `session`, `summary`); `save-markdown` writes it to `docs/sessions/yyyymmdd-topic.md` with collision-safe names. Search first, then export: `claude-nu -f 'auth refactor' | claude-nu export-session`.

Combine with nu-goodies for review-before-export:

```nushell
claude-nu sessions | claude-nu messages | fzf-preview --content   # skim past prompts with preview
claude-nu sessions | claude-nu messages | in-vd                   # or explore them in VisiData
```

### `ask` — one-shot Claude inside a pipeline

```nushell
use claude-nu/ask.nu *
open error.log | ask 'what is the likely root cause?'
ask --collect 'one-line summary of git rebase' | save -f note.md
```

Merges the prompt with piped stdin, streams the answer live, `--collect` returns it as a string for further piping, `--here` runs in the project directory so Claude sees the repo context. This makes the AI a composable pipeline stage — the terminal-native version of "ask a quick question".

### The dotnu-captures pattern — tracking external drift with git

claude-nu's repo demonstrates a pattern worth copying. `dotnu-captures/nu--help.nu` contains:

```nushell
# Capture `nu --help` output for tracking flag changes via git diff.
# Update with: `dotnu embeds-update dotnu-captures/nu--help.nu`

nu --help | print $in
# => ...entire help text as # => lines...
```

After a Nushell upgrade, `dotnu embeds-update dotnu-captures/nu--help.nu` re-captures, and `git diff` shows exactly which flags changed. Any external tool's `--help`, any API response shape, any environment fact can be pinned this way: a capture file per fact, refreshed by one command, diffed by git.

### Completions that help the loop

`completions/claude.nu` gives `claude --resume <TAB>` a human session picker (age, size, summary instead of UUIDs); `completions/nu.nu` parses any `.nu` script at tab-time so `nu toolkit.nu <TAB>` offers its subcommands.
