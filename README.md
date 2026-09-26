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
/plugin install nushell-history@nushell-skills
/plugin install claude-nu@nushell-skills
```

## Plugins

- **nushell-completions** — teaches Claude Code to write Nushell completions: inline lists, custom completers, `extern` definitions, module naming rules.
  Point it at `--help` output and it produces a ready-to-use completion file.
- **nushell-style** — opinionated Nushell style guide: pipeline patterns, command choices, formatting conventions, testing patterns.
  Activates automatically when editing `.nu` files.
- **nushell-history** — inspects and rewrites the Nushell sqlite command history: `history --long | where ...` recipes and `nu-history-tools` mutation flows (retag cwd, remove entries).
- **claude-nu** — reads Claude Code session transcripts with the `claude-nu` module instead of jq or python: what the user said, what agents ran and what came back, raw records, per-session numbers.

## Development

`toolkit.nu` provides convenience commands for skill development:

```nushell no-run
nu toolkit.nu vendor           # Copy from ~/.claude/skills into plugin directories
nu toolkit.nu install-locally  # Copy from plugin directories to ~/.claude/skills for testing
```

## License

MIT
