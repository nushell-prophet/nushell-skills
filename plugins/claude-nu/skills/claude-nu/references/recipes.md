# Recipes: past mining intents, redone with claude-nu

Each recipe is an intent that past agents on this machine served with jq, python or grep over `~/.claude/projects`, grouped from about 3,500 of their commands.
Every pipeline here was run against a real store; the time is what it took over the whole machine (174 projects, 5,300 transcripts), so scope it down when you can.

## The user's words

```nu
# The user's messages in one session (the prompt list past agents rebuilt most)
claude-nu sessions --session '9787e004' | claude-nu messages

# Every session where a phrase was said, across every project (2.5 s)
claude-nu projects | claude-nu messages 'virtiofs' | get session | uniq

# How much the user typed per month, without `!` commands and their output (27 s)
claude-nu projects | claude-nu messages | where kind == typed
| group-by { get timestamp | format date '%Y-%m' }
| items {|month rows| {month: $month messages: ($rows | length)} }

# The assistant reply the user was answering, and the one after (1 s)
claude-nu projects | claude-nu messages 'dropped --rename' --context 1 --include-responses
| select hit role message
```

## What the agents ran

```nu
# The whole bash corpus of the machine (58 s; a project takes about a second)
claude-nu projects | claude-nu tool-calls --tool Bash | get input.command

# Calls through the nushell MCP server, whose command sits in input.input (8 s)
claude-nu projects | claude-nu tool-calls --tool mcp__nushell__evaluate 'claude-nu' | get input.input

# Which skills the agents picked on their own (14 s)
claude-nu projects | claude-nu tool-calls --tool Skill | get input.skill | uniq --count | sort-by count --reverse

# What the agent said right before each tool call
claude-nu sessions --last | claude-nu timeline | window 2
| where {|w| $w.0.kind == text and $w.1.kind == tool_use } | each {|w| {said: $w.0.text tool: $w.1.tool} }

# Which slash commands the user typed (4 s)
claude-nu projects | claude-nu slash-commands | get command | uniq --count | sort-by count --reverse

# The files one session edited
claude-nu sessions --session '9787e004' --columns edited_files | get 0.edited_files
```

## What came back

```nu
# Which tools fail most in one project (12 s for a large one)
claude-nu projects | where name =~ 'cozy$' | claude-nu tool-calls --results
| where is_error == true | get tool | uniq --count | sort-by count --reverse

# Which session printed a string that no message or command contains
claude-nu projects | where name =~ 'cozy$' | claude-nu tool-calls --results 'Permission denied'
| select timestamp session tool
```

## Sessions and their shape

```nu
# One row per session with its time span and size
claude-nu sessions --columns first_timestamp,last_timestamp,user_msg_count,turn_count,size

# The largest projects, and the largest sessions of this one (no session file is parsed)
claude-nu projects | sort-by size --reverse | first 5 | select name size count
claude-nu sessions --columns size,modified | sort-by size --reverse | first 5

# Sessions open at some point on a given day, by record time, not file mtime (2 s)
claude-nu sessions --all-projects --active-since 2026-09-20 --active-until 2026-09-21 --columns summary,first_timestamp,last_timestamp

# Calls per tool in one session — a Workflow run shows as its own tool
claude-nu sessions --session 'd302c6e9' --columns tool_counts | get 0.tool_counts

# The subagents of a session in the current project, and which agent each one was
claude-nu sessions --subagents --columns agent_type,agent_label,summary | where parent_session_id =~ '^9787e004'

# Workflow runs across every project, the longest first (1 s); `agents` lists each run's agents
claude-nu projects | claude-nu workflows | sort-by duration --reverse | select id name status duration agent_count project_name

# The agents of workflow runs as transcripts: their run, label and phase (9 s)
claude-nu sessions --all-projects --subagents --columns workflow,agent_label,phase | where workflow != null

# Every record type in the current project's transcripts, and one type's fields
claude-nu records | get type | uniq --count
claude-nu records | where type == system | get record | first | columns
```

## Not claude-nu's job

About 1,500 of the past commands ran jq or python over corpora built from transcripts (a `harvest/*.jsonl` of the user's words, theme files), not over the transcripts.
Once such a corpus exists, query it as the data it is: `open harvest/prompts.jsonl | from json --objects | where ...`.
When a corpus exists only to have the user's words with an address back to the record, `claude-nu projects | claude-nu messages | select uuid session timestamp message` is that corpus, rebuilt on demand.
