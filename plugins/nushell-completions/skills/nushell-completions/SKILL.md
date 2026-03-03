---
name: nushell-completions
description: Generate Nushell custom completions for CLI commands. Use when creating completers, adding tab-completion to extern commands, or building context-aware argument suggestions.
---

# Nushell Custom Completions

Generate completions for Nushell commands following these patterns.

## Quick Reference

| Syntax | Use Case | Nu Version |
|--------|----------|------------|
| `string@[a b c]` | Inline static list | 0.108+ |
| `string@$const_list` | Const variable | 0.108+ |
| `string@completer` | Custom completer function | all |
| `@complete fn` | Command-wide completer | 0.108+ |

## Inline Completions (Nu 0.108+)

Simplest approach for static options:

```nu
# Inline list directly in signature
def go [direction: string@[left up right down]] { $direction }

# Using const variable
const directions = [left up right down]
def go [direction: string@$directions] { $direction }
```

## Command-Wide Completers (Nu 0.108+)

Use `@complete` attribute for all arguments of a command:

```nu
# Use the global external completer
@complete external
def --wrapped jc [...args] { ^jc ...$args | from json }

# Use a specific completer for all args
def carapace-completer [spans: list<string>] {
    carapace $spans.0 nushell ...$spans | from json
}

@complete carapace-completer
def --env get-env [name] { $env | get $name }

# For extern wrappers
@complete fish-completer
extern git []
```

## Custom Completer Functions

For dynamic completions:

```nu
# Simple completer
def "nu-complete git remotes" [] {
    git remote | lines
}

# With descriptions
def "nu-complete branches" [] {
    git branch --format='%(refname:short)|%(subject)'
    | lines
    | split column '|' value description
}

# Context-aware (uses previous arguments)
def "nu-complete git branches" [context: string] {
    let remote = $context | split words | get 2?
    if $remote != null {
        git branch -r | lines | str trim | where { str starts-with $remote }
    } else {
        git branch | lines | str trim
    }
}

# Attach to command
def my-cmd [
    remote: string@"nu-complete git remotes"
    branch: string@"nu-complete git branches"
] { ... }
```

## Completer Patterns

| Pattern | Return Type | Use Case |
|---------|-------------|----------|
| Inline list | `@[a b c]` | Static options (simplest) |
| Simple list | `list<string>` | Dynamic options |
| With descriptions | `list<record<value, description>>` | Options needing explanation |
| With options | `record<completions, options>` | Custom sorting/matching |
| Context-aware | Accept `context: string` param | Depends on previous args |
| Null return | `null` | Fall back to file completions |

## With Matching Options

```nu
def "nu-complete commands" [] {
    {
        options: {
            case_sensitive: false
            completion_algorithm: fuzzy
            sort: false  # preserve original order
        }
        completions: [
            { value: "build", description: "Build the project" }
            { value: "test", description: "Run tests" }
        ]
    }
}
```

## For Extern Commands

```nu
export extern "git push" [
    remote?: string@"nu-complete git remotes"
    refspec?: string@"nu-complete git branches"
    --force(-f)
    --set-upstream(-u)
]
```

## Module Naming Rule

When the file is named after the command (e.g., `chafa.nu`), the extern **must** be named `main`:

```nu
# File: chafa.nu
# Import: use chafa.nu

# ❌ WRONG - "Can't export known external named same as the module"
export extern chafa [...]

# ✅ CORRECT - `main` becomes the module's default command
export extern main [...]
```

## Completer Signature Options

```nu
def completer [] { ... }                          # simple
def completer [context: string] { ... }           # with command line
def completer [context: string, pos: int] { ... } # with cursor position
def completer [spans: list<string>] { ... }       # for @complete (list of args)
```

## Best Practices

1. **Prefer inline** `@[a b c]` for small static lists
2. **Use const** `@$var` for reusable static lists
3. **Naming**: Use `nu-complete <command> <what>` pattern for functions
4. **Module scope**: Define completers as private, export only the command
5. **Dynamic data**: Shell out to get live values (`git remote | lines`)
6. **Suppress completions**: Return `[ ]` for args accepting any value
7. **File fallback**: Return `null` to use Nushell's file completions

## Record Fields

| Field | Type | Description |
|-------|------|-------------|
| `value` | string | The completion text |
| `description` | string? | Shown in menu |
| `style` | string/record? | Color: `"red"`, `{fg: green, bg: black, attr: b}` |

## Options Record

| Option | Values | Default |
|--------|--------|---------|
| `sort` | `true`/`false` | `true` |
| `case_sensitive` | `true`/`false` | from config |
| `completion_algorithm` | `prefix`/`substring`/`fuzzy` | from config |
