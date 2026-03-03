# NUON (Nushell Object Notation)

NUON is Nushell's native data format—a superset of JSON that supports most Nushell data types. NUON code is valid Nushell code that describes data structures.

## Overview

| Feature | JSON | NUON |
|---------|------|------|
| Strings | `"text"` | `"text"` or `'text'` |
| Numbers | `123`, `1.5` | `123`, `1.5`, `0xff`, `0o755`, `0b1010` |
| Booleans | `true`/`false` | `true`/`false` |
| Null | `null` | `null` |
| Lists | `[1, 2, 3]` | `[1 2 3]` (commas optional) |
| Records | `{"a": 1}` | `{a: 1}` |
| Dates | not supported | `2024-01-15T10:30:00Z` |
| Durations | not supported | `5min`, `2hr`, `100ms` |
| File sizes | not supported | `64mb`, `512kb`, `2gib` |
| Binary | not supported | `0x[DEADBEEF]` |
| Ranges | not supported | `1..5`, `0..<10` |
| Comments | not supported | `# comment` |
| Closures/Blocks | N/A | **not supported** |

**Key point:** Any valid JSON is valid NUON, but NUON cannot serialize closures or blocks.

## Converting Data

```nushell
# Convert to NUON
{name: 'test', count: 42} | to nuon

# Convert from NUON
'{name: test, count: 42}' | from nuon

# Pretty print with indentation
$data | to nuon --indent 2

# Compact single-line output
$data | to nuon --indent 0

# Use tabs instead of spaces
$data | to nuon --tabs
```

## Common Patterns

### Configuration Files

NUON is ideal for config files—more readable than JSON, native Nushell types:

```nushell
# config.nuon
{
    timeout: 30sec
    max_size: 10mb
    ports: [8080 8443]
    debug: false
    # Comments are allowed
    created: 2024-01-15T00:00:00Z
}
```

```nushell
# Reading config - types are preserved
let config = open config.nuon
$config.timeout  # => 30sec (duration type, not string or number)
```

### Inline Data in Scripts

```nushell
# Embed structured data directly (this IS valid NUON)
const endpoints = [
    {host: 'api.example.com', port: 443, timeout: 10sec}
    {host: 'backup.example.com', port: 443, timeout: 30sec}
]
```

### Data Serialization

```nushell
# Save structured data
$results | to nuon | save results.nuon

# Load and process
open results.nuon | where status == 'passed'
```

## Syntax Details

### Strings

```nushell
# Double quotes (escape sequences work)
"line1\nline2"

# Single quotes (literal, no escapes)
'C:\path\to\file'

# Bare strings in records (no spaces/special chars)
{key: value}  # equivalent to {key: 'value'}
```

### Numbers

```nushell
# Integers
42
-17
1_000_000  # underscores for readability

# Floats
3.14
1.5e-10

# Hex, octal, binary
0xff
0o755
0b1010
```

### Lists and Records

```nushell
# Lists - commas optional
[1 2 3]
[1, 2, 3]
['a', 'b', 'c']

# Nested structures
{
    users: [
        {name: 'alice', role: 'admin'}
        {name: 'bob', role: 'user'}
    ]
    settings: {
        theme: 'dark'
        timeout: 5min
    }
}
```

### Tables

Tables are lists of records with consistent keys:

```nushell
# Compact table syntax
[
    [name age];
    ['Alice' 30]
    ['Bob' 25]
]

# Or as list of records
[
    {name: 'Alice', age: 30}
    {name: 'Bob', age: 25}
]
```

## Best Practices

### Use NUON for Nushell-Specific Data

```nushell
# Preferred: native types preserved
{timeout: 30sec, size: 10mb} | to nuon
# => {timeout: 30sec, size: 10mb}

# Avoid: loses type information
{timeout: 30sec, size: 10mb} | to json
# => {"timeout": 30000000000, "size": 10000000}
```

### Use `--indent` for Human-Readable Files

```nushell
# Config files - readable
$config | to nuon --indent 2 | save config.nuon

# Data interchange - compact
$data | to nuon --indent 0 | save data.nuon
```

### Validate with `from nuon`

```nushell
# Check if string is valid NUON
def is-valid-nuon []: string -> bool {
    try {
        $in | from nuon | ignore
        true
    } catch {
        false
    }
}
```

## NUON vs JSON

| Use NUON when | Use JSON when |
|---------------|---------------|
| Nushell-only workflows | Interoperability with other tools |
| Need durations, sizes, dates | External API requirements |
| Config files for Nu scripts | Web APIs, cross-language data |
| Human-edited data files | Standard data exchange |

## Common Commands

```nushell
# File operations
open file.nuon              # parse as NUON (auto-detected by extension)
$data | save file.nuon      # auto-detects format from extension

# Explicit conversion
$data | to nuon             # convert to NUON string
'...' | from nuon           # parse NUON string

# Pretty printing
$data | to nuon --indent 4  # indented output
$data | to nuon --tabs      # use tabs instead of spaces
```
