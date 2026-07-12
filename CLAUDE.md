# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin marketplace providing opinionated Nushell development skills. It contains three plugins distributed via the Claude Code plugin system:

- **nushell-completions** — teaches Claude to generate Nushell tab-completion definitions (inline lists, custom completers, `extern` definitions, module naming)
- **nushell-style** — opinionated Nushell style guide (pipeline patterns, command choices, formatting, testing, debugging)
- **nushell-history** — inspecting and rewriting the user's sqlite command history (`history --long | where ...` recipes, `nu-history-tools` mutation flows)

## Architecture

```
.claude-plugin/marketplace.json    # Marketplace manifest — lists plugins with metadata
plugins/
  nushell-completions/
    .claude-plugin/plugin.json     # Plugin manifest
    skills/nushell-completions/
      SKILL.md                     # The skill content (completions reference)
  nushell-style/
    .claude-plugin/plugin.json     # Plugin manifest
    skills/nushell-style/
      SKILL.md                     # Main skill (quick reference, do/don't checklists)
      references/                  # Detailed reference docs loaded by SKILL.md
        patterns.md                # Pipeline composition, code structure examples
        formatting.md              # Topiary conventions, spacing, declarations
        debugging.md               # nu --ide-check diagnostics, agent workflow
        nuon.md                    # NUON format, data serialization
        testing.md                 # nutest framework, snapshots, coverage
        toolkit.md                 # toolkit.nu patterns, commit conventions
        mcp.md                     # nu --mcp server, tools, persistent state
  nushell-history/
    .claude-plugin/plugin.json     # Plugin manifest
    skills/nushell-history/
      SKILL.md                     # History inspection + mutation reference
toolkit.nu                         # Dev convenience commands (not distributed)
```

The marketplace manifest (`.claude-plugin/marketplace.json`) is the entry point. Each plugin has its own `plugin.json` and a `skills/` directory containing `SKILL.md` (the actual content Claude receives).

## Development Commands

```nushell
# Copy skills FROM ~/.claude/skills INTO plugin directories (for publishing)
nu toolkit.nu vendor

# Copy skills FROM plugin directories TO ~/.claude/skills (for local testing)
nu toolkit.nu install-locally

# Vendor without auto-committing
nu toolkit.nu vendor --no-commit

# Force overwrite even with uncommitted changes in destination
nu toolkit.nu install-locally --force
```

## Development Workflow

The canonical source of skill content can live in either location depending on the workflow:

1. **Edit in `~/.claude/skills/`** (live testing) -> `nu toolkit.nu vendor` to sync into repo
2. **Edit in `plugins/`** (repo-first) -> `nu toolkit.nu install-locally` to test locally

`vendor` auto-commits changes to the `plugins/` directory. `install-locally` checks for uncommitted changes in `~/.claude/skills/` before overwriting (use `--force` to skip).

The managed skills list is defined as `const managed_skills` in `toolkit.nu`.

## Local Nushell Sources (fact-check against these, not WebFetch)

Sibling directories of this repo hold canonical Nushell material. When updating skills for a new Nushell release or verifying a claim, read these instead of fetching the web:

| Path | Contents |
|---|---|
| `../nushell-docs/` | Sparse shallow clone of nushell.github.io (`blog/`, `book/`, `cookbook/`, `commands/`). Release notes: `blog/<date>-nushell_v0_<minor>_<patch>.md`. Refresh with `git pull` (or `claude-nu fetch-nushell-docs`). Default lookup target — small and fast to grep. |
| `../nushell.github.io/` | Full clone incl. `lang-guide/`, `contributor-book/`, translations. The user works in it (branches, stashes) — no destructive git commands. |
| `../nushell/` | Nushell source. Ground truth for command signatures (`crates/nu-command/`, `crates/nu-cli/`) and std (`crates/nu-std/std/`). Release-note prose is sometimes imprecise — verify flags and behavior here. |

## Highest-Priority Guidance Lives Elsewhere

The skills in this repo aren't always loaded — a session only pulls a skill in when its trigger matches. But Nushell is the main tool in the cozy sandbox environment, so the most critical pitfalls and rules must not depend on skill activation. Put those in `../cozy/docker-files/global-claude.md` (baked into every sandbox session as global memory); keep this repo's skills for the full, detailed guidance.

## Editing Skills

Skill content is Markdown. The `SKILL.md` files use YAML frontmatter (`name`, `description`) and can reference files in a `references/` subdirectory. When editing:

- Keep `SKILL.md` as a quick-reference entry point with tables and checklists
- Put detailed examples and explanations in `references/*.md`
- Ensure code examples follow the opinionated conventions in the style guide

## Versioning

`nushell-style` tracks Nushell in its **minor** segment (DefinitelyTyped-style): `1.<nushell-minor>.<patch>`, e.g. `1.114.0` covers Nushell 0.114, and `1.114.1`, `1.114.2`… are our own edits between Nushell releases. Bump the minor when a new Nushell release is folded in. The other plugins version independently.

## Commit Conventions

Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`
