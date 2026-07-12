---
name: nushell-literate-programming
description: This skill should be used for literate programming in Nushell — executable markdown documents (numd), .nu scripts that embed their own output as `# =>` comments (dotnu), capturing REPL sessions into documents, keeping READMEs and examples verifiably current, and archiving Claude Code sessions as markdown (claude-nu). Relevant when the user says "numd," "dotnu," "run the code blocks in this markdown," "update the embeds," "refresh the outputs," "capture this session," "keep this doc in sync," "literate programming," "executable documentation," "export this claude session," "self-updating README," or asks how to document, share, or verify Nushell explorations.
---

# Nushell Literate Programming

In this environment, documents and code are not separate artifacts. A markdown file runs; a script carries its own output; a REPL session becomes a document; an AI conversation becomes a doc in `docs/sessions/`. The unifying convention is the `# => ` comment — output embedded next to the code that produced it — and the unifying discipline is **commit → refresh → read the diff**: git shows whether reality still matches the document.

Four modules cooperate (all preloaded in cozy sandboxes; elsewhere `use numd`, `use dotnu/`, `use nu-goodies *`, `use claude-nu`):

| Module | Owns | Core command |
|---|---|---|
| **numd** | Markdown with executable ```` ```nu ```` blocks | `numd run file.md` |
| **dotnu** | `.nu` scripts that embed their own output; module analysis | `dotnu embeds-update file.nu` |
| **nu-goodies** | Capturing and presenting what happened in the terminal | `example`, `copy-out` |
| **claude-nu** | Claude Code sessions as data and as markdown | `claude-nu export-session` |

## Contents

| File | Topic |
|------|-------|
| **This file** | Which tool when, core loop, agent checklist |
| [numd.md](references/numd.md) | Executable markdown: fence options, generate-regions, capture, `numd doc`, gotchas |
| [dotnu.md](references/dotnu.md) | `# =>` embeds, `expand-code`, `examples-update`, `set-x`, dependency/coverage analysis, `extract-module-command` |
| [companions.md](references/companions.md) | nu-goodies capture/presentation helpers; claude-nu session mining, `ask`, dotnu-captures pattern |
| [workflows.md](references/workflows.md) | End-to-end flows: capture → promote → maintain; the AI-companion loop |

## Which tool, when

| Situation | Reach for |
|---|---|
| Writing a tutorial, README, or blog post with live examples | numd: ```` ```nu ```` blocks, `numd run` |
| A `.nu` script whose results should be visible in the source | dotnu: end lines with `\| print $in`, run `embeds-update` |
| Exploring in the REPL, want a record | `numd capture start` (decided beforehand) / `copy-out`, `example` (after the fact) |
| One good pipeline worth keeping | `dotnu embed-add` — appends it + output to a capture file |
| Command docs that must match real signatures | generate-region around `numd doc '<cmd>'` |
| `@example --result` values gone stale | `dotnu examples-update` |
| Pin an external fact (`tool --help`, API shape) and watch it drift | capture file + `dotnu embeds-update`, diff with git |
| Which script block is slow / what does no test cover | `dotnu set-x` / `dependencies \| filter-commands-with-no-tests` |
| Turn an AI working session into a permanent doc | `claude-nu export-session \| claude-nu save-markdown` |
| Find how a past session solved something | `claude-nu -f 'regex' [--all-projects]` |

## The core loop

```nushell
git commit -am 'wip'        # the safety net; numd enforces it, dotnu deserves it
numd run doc.md             # or: dotnu embeds-update script.nu
git diff                    # empty = docs proven current; non-empty = drift caught
```

All executors run in a clean `nu -n` process — no user config, no `$env` leakage. Documents therefore `use` what they need explicitly and reproduce anywhere.

## Do

- Preview with `numd run --echo` / `--dry-run` / `dotnu embeds-update --echo` before any in-place write
- Let git gate in-place runs: commit first, then refresh, then read the diff
- Mark illustration-only blocks `nu no-run`; error demos `nu try, new-instance`; one-shot side effects `nu run-once`
- Keep `| print $in` markers on top-level lines only (a marker inside a loop breaks capture alignment)
- Regenerate command references with `numd doc` in generate-regions instead of hand-writing them
- Archive substantial AI sessions: `claude-nu export-session 'topic' | claude-nu save-markdown`
- Share snippets in the common dialect: `example` / `copy-out` produce `# =>`-annotated, runnable text

## Don't

- Hand-write `# => ` lines — they are volatile; every refresh overwrites them
- Rely on interactive config inside blocks — executors run `nu -n`; `use` modules explicitly in the doc
- Use `--ignore-git-check` as a habit — untracked files already pass the gate; the flag skips review of tracked changes
- Expect isolation between blocks in one numd file — they share a process; `new-instance` isolates a block only combined with `try`
- Mistype fence options and hope — unknown options are hard errors by design (a typo'd `no-run` must not execute)
- Paste command output into docs manually — that's the drift the whole toolchain exists to prevent
