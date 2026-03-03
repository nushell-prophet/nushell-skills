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

Resolve byte spans to line numbers and source content (eliminates manual lookup):

```nushell
def diagnose [file: path] {
    let content = open --raw $file
    let source_lines = $content | lines

    nu --ide-check 10 $file | lines | each { from json }
    | where type == "diagnostic"
    | each {|d|
        let before = $content | str substring 0..<$d.span.start
        let line_num = $before | split row "\n" | length
        {
            line: $line_num
            severity: $d.severity
            message: $d.message
            source: ($source_lines | get ($line_num - 1) | str trim)
            span: ($content | str substring $d.span.start..<$d.span.end)
        }
    }
    | uniq
}
```

**Key details:**
- `open --raw` preserves byte positions matching `--ide-check` spans
- `..<` exclusive ranges match the exclusive `span.end` from diagnostics
- `source` shows the full trimmed line; `span` shows the exact flagged text
- `uniq` deduplicates identical diagnostics (common with mutable capture errors)

## Agent Workflow

1. Run `--ide-check` first (catches static errors)
2. Parse spans to get line numbers and source context — no manual file lookup needed
3. If no static errors, run the file for runtime errors
