# Nushell MCP Server

Nushell has a built-in MCP (Model Context Protocol) server, started with `nu --mcp`. It runs as a stdio server and exposes Nushell's shell capabilities as tools.

## Adding to Claude Code

```bash
claude mcp add --transport stdio nushell -- nu --mcp
```

## Tools

| Tool | Purpose |
|------|---------|
| `evaluate` | Execute Nushell or shell commands, returns structured output |
| `list_commands` | List/search available Nushell native commands |
| `command_help` | Get detailed help for a specific command (flags, types, examples) |

## Key Behaviors

**Persistent state** — variables and environment changes persist across `evaluate` calls (REPL-style):

```nu
# Call 1
let x = 42
# Call 2
$x  # → 42
```

**Structured output** — native Nushell commands return NUON, not text. No need to pipe to `to json`.

**History** — `$history` stores all previous command outputs as `list<any>`:

```nu
# Access previous results
$history.0        # first command output
$history | last   # most recent output
```

Ring buffer, 100 entries by default. Configure with `$env.NU_MCP_HISTORY_LIMIT`.

**Truncation** — large outputs are stored in `$history` but truncated in the response. Enable with `$env.NU_MCP_OUTPUT_LIMIT`:

```nu
$env.NU_MCP_OUTPUT_LIMIT = 10kb
```
