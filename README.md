# nushell-skills

[Claude Code](https://claude.ai/code) plugin marketplace with opinionated Nushell development skills.

## Installation

```
/plugin marketplace add nushell-prophet/nushell-skills
```

Then install the plugins you want:

```
/plugin install nushell-completions@nushell-skills
/plugin install nushell-style@nushell-skills
```

## Plugins

| Plugin | What it does |
|--------|-------------|
| **nushell-completions** | Teaches Claude Code to write Nushell completions — inline lists, custom completers, `extern` definitions, module naming rules. Point it at `--help` output and it produces a ready-to-use completion file. |
| **nushell-style** | Opinionated Nushell style guide — pipeline patterns, command choices, formatting conventions, testing patterns. Activates automatically when editing `.nu` files. |

## Development

`toolkit.nu` provides convenience commands for skill development:

```nushell
nu toolkit.nu vendor           # Copy from ~/.claude/skills into plugin directories
nu toolkit.nu install-locally  # Copy from plugin directories to ~/.claude/skills for testing
```

## License

MIT
