---
name: claude-nu
description: This skill should be used whenever you need something out of Claude Code session transcripts (`~/.claude/projects/**/*.jsonl`) — what the user said and when, the session where something was decided, what an agent ran and what it returned, which tool calls failed, the raw shape of a record type, token or tool counts per session. Reach for it before writing jq, python or grep over those files: the user's `claude-nu` Nushell module already does the parsing, the filtering and the scoping.
---

# claude-nu — Claude Code sessions as tables

Every Claude Code session is a JSONL file under `~/.claude/projects/<encoded project path>/`, subagents under `<session>/subagents/`.
Past agents on this machine wrote 3,191 jq, python and shell commands against these files and the corpora built from them, and each one rewrote the same filters: keep `type == "user"`, drop tool results and the wrappers Claude Code writes itself, join `tool_use` to `tool_result` by id.
`claude-nu` is those filters, once.
Do not parse the transcripts by hand; when claude-nu cannot answer, `claude-nu records` still hands you every raw line as a row.

## Load it

In a cozy sandbox it is autoloaded for interactive nu, including the nushell MCP `evaluate` tool.
From the Bash tool, `nu --commands` skips autoload: `nu --config ~/.config/nushell/autoload/modules-core.nu --commands '...'`, or put `use claude-nu` at the top of a script file and run `nu file.nu` — nu inside bash quotes is painful.
Elsewhere: `use /path/to/claude-nu/claude-nu`.
End every pipeline you are going to read with `| to nuon`.

## The one rule: scope is to the left of the pipe

Every command reads the sessions piped into it; with no input, the current project's top-level sessions.

- The current project: nothing piped.
- One session: `claude-nu sessions --session <selector> | ...`. The selector is a UUID, a unique id prefix (`'9787e004'`, quoted — bare, it parses as a file size), a subagent id (`agent-a1b2...`), a `/rename` name, or a path.
- The whole machine: `claude-nu projects | ...` — each project row stands for its top-level sessions.
  Not `claude-nu sessions --all-projects | ...`: the same set, but it parses every file for session columns first (40 s against 2.4 s).
- Subagent transcripts too: `claude-nu sessions --subagents | ...`.
- Any list: `glob .../*.jsonl | ...`, `['9787e004' 'agent-a1'] | ...`.
- Any result: every row carries `session`, so `claude-nu messages 'x' | claude-nu tool-calls` reads the sessions where x was said.

## Commands, by what you want

- **What the user said**: `claude-nu messages 'regex'`.
  Rows `{message, kind, timestamp, uuid, session, project, project_name}`.
  `where kind == typed` keeps the user's own words; the other kinds are `bash-input` and `bash-output` (a `!` command and its output), `system`, `response`.
  Already dropped: tool results, slash-command and hook wrappers, turns that open with `<system-reminder>`, `[Request interrupted by user]`, and the copies a resumed session makes of its parent's records.
  `--include-responses` adds the assistant's text (a `role` column), `--include-system` keeps the wrappers, `--raw` gives the records.
  `--context N` also returns the N rows before and after each hit in its session; `hit` marks the matches.
- **What the agent did**: `claude-nu tool-calls 'regex'` — the regex matches the tool name or the input rendered as NUON.
  Rows `{tool, input, timestamp, id, uuid, ...}`.
  One tool: `--tool Bash` or `--tool [Read Edit]`, exact names with their own rg pre-filter, so a rare tool is found 5x faster than with `where tool == ...` machine-wide.
  The nushell MCP tool keeps its command in `input.input`.
- **What came back**: `claude-nu tool-calls --results` adds `result` and `is_error`; the regex then searches results too.
  It parses whole files, so ask for it when you need it.
- **Both, in file order**: `claude-nu timeline` — one row per text, thinking, tool_use or tool_result block, `{role, kind, text, tool, id, is_error, ...}`; for "what came right before this call".
- **Workflow tool runs**: `claude-nu workflows` — one row per run, `{id, status, duration, error, name, phases, agents, ...}`.
  A subagent row of `sessions --subagents` names itself with the columns `agent_id`, `agent_type`, `workflow`, `agent_label`, `phase`.
- **What the user typed as commands**: `claude-nu slash-commands` (`--all` keeps /clear, /model ...).
- **Anything else in a transcript**: `claude-nu records` — one row per line, `{type, uuid, timestamp, record, ...}`, the whole line under `record`; its regex matches the line as JSON (`records '"permissionMode":"plan"'`).
- **Numbers per session**: `claude-nu sessions --columns a,b` (tab-completes; `--all-columns` for every one).
  `tool_counts`, `token_usage`, `turn_count`, `first_timestamp`, `edited_files`, `git_branch`, `plan_mode_used` ...
  `size` and `modified` come from the file listing and open no file; `projects` rows carry `size` too.
- **A session as markdown**: `... | claude-nu export-session` (`--tools` keeps the calls).

`--since`/`--until` take a duration (`1wk`, meaning ago), a date or a datetime, on `sessions`, `messages`, `tool-calls` and `slash-commands`.
A message or call is compared by its own timestamp, a session by its file mtime.
For a session, `--active-since`/`--active-until` compare its record span instead: it keeps a session that was open inside the window.

## Recipes

Each of these is a past intent from the transcripts, redone; `references/recipes.md` has more.

```nu
# Where did the user say it, across every project
claude-nu projects | claude-nu messages 'semantic.feed' | select timestamp project_name message

# The turns around a hit: the reply the user was answering, and the one after
claude-nu projects | claude-nu messages 'dropped --rename' --context 1 --include-responses

# Which session ran a command, and what it printed. --results parses whole
# files: one project takes seconds, the whole machine a minute.
claude-nu projects | where name =~ 'claude-nu' | claude-nu tool-calls --results --tool Bash 'git commit'
| where input.command =~ 'git commit' | select timestamp session result

# What failed in the last session
claude-nu sessions --last | claude-nu tool-calls --results | where is_error == true | select tool input result
```

## Pitfalls

- A datetime column renders as "4 months ago"; `format date '%F %T'` when you quote it.
- Rows come session by session, newest session first; `sort-by timestamp` for one timeline.
- `sessions` rows name a session `session_id`; `messages`, `tool-calls` and `records` rows name it `session`. Both pipe onward.
- A regex with a line anchor or a JSON-escaped character can hide from the rg pre-filter over the raw file; `--no-rg` matches in-engine.
- A plain `rg` over `~/.claude` can return nothing, silently: on this machine `~/.claude` is a git repo whose `.gitignore` is `*`. claude-nu passes `--no-ignore`; a hand-rolled rg needs it too.

The worked chapters with their real outputs are the claude-nu repo's `guide/*.nu` (dotnu embeds).
