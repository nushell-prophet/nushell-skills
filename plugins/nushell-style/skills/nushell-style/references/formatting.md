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

```nushell
# Preferred
--noinit (-n)
--restore (-r)

# Avoid
--noinit(-n)
```

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
let original_md = open -r $file

# Avoid (older style)
let $original_md = open -r $file
```
