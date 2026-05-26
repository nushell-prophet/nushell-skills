---
name: nushell-history
description: This skill should be used when inspecting, querying, or rewriting the user's Nushell command history. Relevant when the user asks "what did I run", "show my recent commands", "what was I trying", "find commands I ran in <dir>", "remove these history entries", "move/retag these history entries to <path>", "fix the cwd on these rows", or when you need to understand what the user has been doing in a directory by looking at their shell history.
---

# Nushell history — inspect and rewrite

The user's command history is in a sqlite database (file_format = sqlite). Use the builtin `history` command for reading and `nu-history-tools` for mutation. Never hand-roll SQL against `history.sqlite3` — the builtin and the module already cover every case.

## Inspection (read-only)

`history --long` returns a table with these columns:

| Column           | Type     | Notes                            |
|------------------|----------|----------------------------------|
| `item_id`        | int      | Stable primary key               |
| `start_timestamp`| datetime | Already a datetime — no decoding |
| `command`        | string   | The command line                 |
| `session_id`     | int      |                                  |
| `hostname`       | string   |                                  |
| `cwd`            | string   | Absolute working directory       |
| `duration`       | duration |                                  |
| `exit_status`    | int      | 0 on success                     |
| `idx`            | int      | Row number in the returned table |

### Recipes

```nu
# Last 20 commands the user ran in the current directory
history --long | where cwd == $env.PWD | last 20

# Last 20 failures, anywhere
history --long | where exit_status != 0 | last 20

# Search for what the user tried — e.g. apt-get fumbles in this dir
history --long | where cwd == $env.PWD | where command =~ '(?i)apt|dpkg'

# All commands in a specific directory, with readable timestamps
history --long | where cwd =~ 'git-learning' | select start_timestamp command exit_status

# Recent activity across all dirs
history --long | last 40 | select start_timestamp cwd command exit_status
```

`where` is the only filter you need — there's no SQL syntax to learn. If the user references "what I just tried", "my last commands", or asks you to interpret what they were doing — run one of these instead of asking.

## Mutation

The `nu-history-tools` module (at `/Users/user/git/ai-sandbox-dev-container/nu-history-tools`) provides the write side:

```nu
use ~/repos/nu-history-tools/nu-history-tools *   # or the absolute path above
```

### Retag cwd (move exercises out of the wrong directory)

`update-entries` writes piped rows back to sqlite, keyed by `item_id`. Whatever columns you pipe in get written; the rest are left alone. Friendly names (`item_id`, `command`, `duration`) are auto-translated to sqlite column names.

```nu
# Move all apt-get exercises from git-learning to a dedicated apt-learning dir
history --long
| where cwd =~ 'git-learning'
| where command =~ '(?i)apt|unminimize|dpkg'
| update cwd '/Users/user/git/apt-learning'
| select item_id cwd
| update-entries
```

The `select item_id cwd` step is mandatory — `update-entries` refuses unknown columns (e.g. `idx` from `history --long`) so the caller has to be explicit about what gets written. Backups go to `<history-dir>/history-backup-<timestamp>.nuon` automatically; pass `--no-backup` to skip.

The same shape works for any field:

```nu
# Fix a typo across history
history --long | where command =~ 'mistpyed' | update command 'mistyped' | select item_id command | update-entries
```

### Remove entries

`query-from-history --remove` deletes rows matching piped-in filter values. It selects on the first column it recognizes (`id`, `command_line`, `session_id`, `cwd`) — pipe just the column you want to filter by.

```nu
# Delete failed apt-get fumbles
history --long | where command =~ 'apt get ' | query-from-history --remove
```

### Look up rows from sqlite by piped filter values

`query-from-history` (without `--remove`) re-queries sqlite for full row data matching piped values. Useful when `history --long` doesn't give you all the columns you need.

## Schema gotcha

The friendly column names from `history --long` differ from the underlying sqlite columns:

| Friendly (`history --long`) | sqlite (`history` table) |
|----------------------------|--------------------------|
| `item_id`                  | `id`                     |
| `command`                  | `command_line`           |
| `duration`                 | `duration_ms`            |

`update-entries` translates these automatically. If you write raw SQL via `open $nu.history-path | query db ...` (don't, unless you must), use the sqlite names.
