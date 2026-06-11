# Nushell MCP Server

Nushell has a built-in MCP (Model Context Protocol) server, started with `nu --mcp`. Included by default since v0.110. It exposes Nushell's shell capabilities as tools.

## Transport

| Transport | Flag | Default | Since |
|-----------|------|---------|-------|
| stdio | `nu --mcp` | Yes | 0.110 |
| HTTP | `nu --mcp --mcp-transport http` | port 8080 | 0.111 |

Set a custom HTTP port with `--mcp-port`:

```bash
nu --mcp --mcp-transport http --mcp-port 3000
```

HTTP transport supports request cancellation, 30-minute idle session cleanup, and structured error codes with line/column details.

## Adding to Claude Code

```bash
# stdio (default)
claude mcp add --transport stdio nushell -- nu --mcp

# HTTP
claude mcp add --transport http nushell --url http://localhost:8080
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

**Truncation** — on by default: responses larger than 10kb are truncated, with the full output still stored in `$history`. Adjust the limit with `$env.NU_MCP_OUTPUT_LIMIT`:

```nu
$env.NU_MCP_OUTPUT_LIMIT = 100kb
```

**Long evaluations become background jobs** (since 0.112) — an `evaluate` call that runs past the promote timeout (default 120sec; 10sec when introduced) or is cancelled by the client is promoted to a background job instead of being discarded. The tool call then errors with a job id; collect the result with `job recv`. Promoted jobs appear in `job list` as `mcp: <command>` and can be stopped with `job kill`. Before a known long-running command, widen the window so it stays synchronous:

```nu
$env.NU_MCP_PROMOTE_AFTER = 10min
```
