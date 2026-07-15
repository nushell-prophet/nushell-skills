# Debugging with `--ide-check`

Use `nu --ide-check` for static analysis—outputs structured JSON diagnostics with precise spans.

## What It Catches

| Error Type | Detected? | Example Message |
|------------|-----------|-----------------|
| Undefined variable | ✅ | `Variable not found.` |
| Type mismatch | ✅ | `Type mismatch.` |
| Missing argument | ✅ | `Missing required positional argument.` |
| Wrong flag | ✅ | `Command doesn't have flag X` |
| Pipeline type error | ✅ | `Command does not support string input.` |
| Unclosed delimiters | ✅ | `Unclosed delimiter.` |
| Unknown command | ❌ | Runtime only (could be external) |

## Parsing Diagnostics

Don't run `--ide-check` raw: it floods stdout with type hints, and its spans are byte offsets. `dotnu diagnose file.nu` keeps only real diagnostics and resolves each span to a line number, the source line, and the exact flagged text:

```nushell no-run
dotnu diagnose file.nu
# => ╭───┬──────┬──────────┬─────────────────────┬──────────────────┬────────────╮
# => │ # │ line │ severity │       message       │      source      │    span    │
# => ├───┼──────┼──────────┼─────────────────────┼──────────────────┼────────────┤
# => │ 0 │    2 │ Error    │ Variable not found. │ print $undefined │ $undefined │
# => ╰───┴──────┴──────────┴─────────────────────┴──────────────────┴────────────╯
```

To see how it works: `view source dotnu diagnose` (it's a short wrapper over `nu --ide-check 10`). If dotnu isn't available, that source is trivial to inline.

## Agent Workflow

1. When you finish writing or editing a `.nu` file, run `dotnu diagnose` on it before considering it done
2. Empty result = no static errors; then run the file for runtime errors
