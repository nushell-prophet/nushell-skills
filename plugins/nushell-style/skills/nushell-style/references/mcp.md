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

**Truncation** — large outputs are stored in `$history` but truncated in the response. Enable with `$env.NU_MCP_OUTPUT_LIMIT`:

```nu
$env.NU_MCP_OUTPUT_LIMIT = 10kb
```
