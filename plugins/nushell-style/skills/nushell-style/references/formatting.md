# Formatting Conventions

These follow Topiary formatter conventions.

## Empty Blocks with Space

```nushell
# Preferred
} else { }
| if $in == null { } else { str join (char nl) }

# Avoid
} else {}
```

## Closure Spacing

Single-expression closures have spaces inside braces:

```nushell
# Preferred
| update line { str join (char nl) }
| each { $in.items.row_type.0 }

# Avoid
| update line {str join (char nl)}
```

## Flag Spacing

Declare a short alias only when the user explicitly asks for one.
When present, separate it from the long name with a space:

```nushell
# Preferred
--keep-order (-k)
--restore (-r)

# Avoid
--keep-order(-k)
```

## Document Flags and Parameters

A `#` comment right after a flag or parameter becomes its description in `help <command>`, `<command> --help`, and tab-completion — Nushell reads it straight out of the signature, so it's the only place to write the description; a doc comment above `def` does not cover individual flags.
Add one whenever the name alone doesn't say what the flag does or when it takes an argument:

```nushell
# Preferred
export def 'main test-unit' [
    --json   # force machine-readable JSON even on a terminal
    --pretty # force the human view even when piped
    --all    # human view: also list passing tests (default: failures only)
] { ... }

# Avoid — reader has to guess what --all means from the name alone
export def 'main test-unit' [--json --pretty --all] { ... }
```

Skip the comment when the name is already the whole explanation (`--force`, `--verbose`).
A single-line comment only — Nushell's parser does not read a second line as more of the description.

## Multi-line Records

```nushell
# Preferred
return {
    filename: $file
    comment: "the script didn't produce any output"
}

# Avoid
return { filename: $file,
    comment: "the script didn't produce any output" }
```

## External Command Parentheses

Avoid unnecessary parentheses around external commands:

```nushell
# Preferred
^$nu.current-exe ...$args $script
| complete

# For multi-line, use parentheses with proper formatting
(
    ^$nu.current-exe --env-config $nu.env-path --config $nu.config-path
    --plugin-config $nu.plugin-path $intermed_script_path
)
```

## Variable Declarations

No `$` prefix on left-hand side:

```nushell
# Preferred
let original_md = open --raw $file

# Avoid (older style)
let $original_md = open --raw $file
```
