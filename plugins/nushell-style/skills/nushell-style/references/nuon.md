# NUON (Nushell Object Notation)

NUON is Nushell's native data format—a superset of JSON that supports most Nushell data types.
NUON code is valid Nushell code that describes data structures.

## Overview

How each feature is written in JSON versus NUON:

- Strings — JSON `"text"`; NUON `"text"` or `'text'`
- Numbers — JSON `123`, `1.5`; NUON `123`, `1.5`, `0xff`, `0o755`, `0b1010`
- Booleans — JSON `true`/`false`; NUON the same
- Null — JSON `null`; NUON the same
- Lists — JSON `[1, 2, 3]`; NUON `[1 2 3]` (commas optional)
- Records — JSON `{"a": 1}`; NUON `{a: 1}`
- Dates — JSON not supported; NUON `2024-01-15T10:30:00Z`
- Durations — JSON not supported; NUON `5min`, `2hr`, `100ms`
- File sizes — JSON not supported; NUON `64mb`, `512kb`, `2gib`
- Binary — JSON not supported; NUON `0x[DEADBEEF]`
- Ranges — JSON not supported; NUON `1..5`, `0..<10`
- Comments — JSON not supported; NUON `# comment`
- Closures/Blocks — not applicable in JSON; **not supported** in NUON either

**Key point:** Any valid JSON is valid NUON, but NUON cannot serialize closures or blocks.
`to nuon --serialize` is the escape hatch: it renders a closure as its source string (`{|| 1 } | to nuon --serialize` → `"{|| 1 }"`), so it survives the export but deserializes as a string, not a closure.

## Converting Data

```nushell
# Convert to NUON
{name: 'test' count: 42} | to nuon

# Convert from NUON
'{name: test, count: 42}' | from nuon

# Pretty print with indentation (0.114+: --pretty is shorthand for --indent 2)
$data | to nuon --pretty
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
    {host: 'api.example.com' port: 443 timeout: 10sec}
    {host: 'backup.example.com' port: 443 timeout: 30sec}
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
        {name: 'alice' role: 'admin'}
        {name: 'bob' role: 'user'}
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
    {name: 'Alice' age: 30}
    {name: 'Bob' age: 25}
]
```

## Best Practices

### Use NUON for Nushell-Specific Data

```nushell
# Preferred: native types preserved
{timeout: 30sec size: 10mb} | to nuon
# => {timeout: 30sec, size: 10mb}

# Avoid: loses type information
{timeout: 30sec size: 10mb} | to json
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

Use NUON when:

- the workflow is Nushell-only
- you need durations, sizes, dates
- it is a config file for Nu scripts
- the data file is human-edited

Use JSON when:

- you need interoperability with other tools
- an external API requires it
- it is a web API or cross-language data
- it is standard data exchange

## Common Commands

```nushell
# File operations
open file.nuon              # parse as NUON (auto-detected by extension)
$data | save file.nuon      # auto-detects format from extension

# Explicit conversion
$data | to nuon             # convert to NUON string
'...' | from nuon           # parse NUON string

# Pretty printing
$data | to nuon --pretty    # 0.114+: --indent 2 shorthand
$data | to nuon --indent 4  # indented output
$data | to nuon --tabs      # use tabs instead of spaces
```

With any indentation flag, `to nuon` (0.114+) aligns table columns:

```nushell
[[name age]; [Alice 30] [Bob 25]] | to nuon --pretty
# [
#   [name,  age];
#   [Alice, 30],
#   [Bob,   25]
# ]
```
