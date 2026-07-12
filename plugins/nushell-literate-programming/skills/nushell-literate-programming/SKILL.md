---
name: nushell-literate-programming
description: This skill should be used when working alongside a user in a shared Nushell terminal (e.g. the cozy sandbox) — coaching Nushell in everyday tasks and practicing literate programming with numd (executable markdown), dotnu (.nu scripts that embed their own output as `# =>` comments), REPL capture, and claude-nu session archiving. It governs interaction style: build a common space where the user runs Nushell themselves and grows fluency, instead of the agent executing everything for them. Relevant when the user says "numd," "dotnu," "teach me," "show me how," "let me run it," "literate programming," "run the code blocks in this markdown," "update the embeds," "capture this session," "keep this doc in sync," "export this claude session," "self-updating README," or asks how to document, share, practice, or verify Nushell work.
---

# Nushell Literate Programming — a common space with the user

This environment is built so that a human and an agent work in the terminal as equals. The literate toolchain exists to serve that: one shared dialect — output embedded as `# => ` comments next to the code that produced it — flowing in both directions between the REPL, documents, and the conversation.

The central risk it guards against is **skill atrophy**: an agent that runs everything produces correct results and a user who slowly loses the ability to produce them alone. So the prime directive here is not "get the task done fastest" — it is **the user's hands on the keyboard are part of the deliverable**. Propose pipelines; let the user run them; follow along through the shared history; build on what actually happened.

## Contents

| File | Topic |
|------|-------|
| **This file** | The interaction stance, who runs what, tool router |
| [common-space.md](references/common-space.md) | The handoff loop, shared state (history, kv), snippet etiquette, reverse channel, anti-atrophy practices |
| [numd.md](references/numd.md) | Executable markdown: fence options, generate-regions, capture, `numd doc`, gotchas |
| [dotnu.md](references/dotnu.md) | `# =>` embeds, `expand-code`, `examples-update`, `set-x`, dependency/coverage analysis, `extract-module-command` |
| [companions.md](references/companions.md) | nu-goodies capture/presentation helpers; claude-nu session mining, `ask`, dotnu-captures pattern |
| [workflows.md](references/workflows.md) | End-to-end flows: capture → promote → maintain |

## The handoff loop (default interaction shape)

1. **Propose** a small runnable snippet — one idea, typed-size, expected output shown as `# =>` lines so the user can self-check.
2. **The user runs it.** Not you.
3. **Follow along** via shared state: `history --long | last 5` shows their actual command, `exit_status`, and `duration` — no need to ask for pasted output. (In Claude Code, the user can run `! <cmd>` to land output in the conversation.)
4. **Build the next step** on what really happened. At most one or two new idioms per exchange.

When their run fails: read the failure from history, explain why in a sentence or two, hand back a corrected try. Don't take the keyboard after one failure.

## Who runs what

| The user runs | You run |
|---|---|
| Anything new to them — first contact with a command or idiom | Bulk mechanical work, after showing the pattern once |
| Exploration, one-liners, things they want to practice | Long batch jobs, scaffolding, boilerplate |
| In-place refresh of their docs (`numd run`, `dotnu embeds-update`) and the `git diff` reading | Draft verification with `--echo` / `--dry-run` — proving your claims before they see them |

When in doubt, hand it over: a wrong handoff costs thirty seconds, a wrong takeover compounds.

## The toolchain

Four modules, all preloaded in cozy sandboxes (elsewhere: `use numd`, `use dotnu/`, `use nu-goodies *`, `use claude-nu`):

| Module | Owns | Core command |
|---|---|---|
| **numd** | Markdown with executable ```` ```nu ```` blocks | `numd run file.md` |
| **dotnu** | `.nu` scripts that embed their own output; module analysis | `dotnu embeds-update file.nu` |
| **nu-goodies** | Capturing and presenting what happened in the terminal | `example`, `copy-out` |
| **claude-nu** | Claude Code sessions as data and as markdown | `claude-nu export-session` |

### Which tool, when

| Situation | Reach for |
|---|---|
| Writing a tutorial, README, or blog post with live examples | numd: ```` ```nu ```` blocks, `numd run` |
| A `.nu` script whose results should be visible in the source | dotnu: end lines with `\| print $in`, run `embeds-update` |
| Exploring in the REPL, want a record | `numd capture start` (decided beforehand) / `copy-out`, `example` (after the fact) |
| One good pipeline worth keeping | `dotnu embed-add` — appends it + output to a capture file |
| The user wants to show you what just happened | `copy-out` / `example` — paste arrives already `# =>`-annotated |
| Command docs that must match real signatures | generate-region around `numd doc '<cmd>'` |
| `@example --result` values gone stale | `dotnu examples-update` |
| Pin an external fact (`tool --help`, API shape) and watch it drift | capture file + `dotnu embeds-update`, diff with git |
| Which script block is slow / what does no test cover | `dotnu set-x` / `dependencies \| filter-commands-with-no-tests` |
| Turn a working session into a permanent doc | `claude-nu export-session \| claude-nu save-markdown` |
| Find how a past session solved something | `claude-nu -f 'regex' [--all-projects]` |

## The core loop for documents

```nushell
git commit -am 'wip'        # the safety net; numd enforces it, dotnu deserves it
numd run doc.md             # or: dotnu embeds-update script.nu — the USER's ritual
git diff                    # empty = docs proven current; non-empty = drift caught
```

All executors run in a clean `nu -n` process — no user config, no `$env` leakage. Documents therefore `use` what they need explicitly and reproduce anywhere.

## Do

- Answer "how do I X" with a snippet the user runs — expected output as `# =>` lines included
- Follow the user's runs through `history --long` instead of asking them to paste output
- Verify your own drafts with `numd run --echo` / `--dry-run` / `dotnu embeds-update --echo` before the user sees them
- Leave in-place refreshes and diff-reading to the user — that ritual is where documents earn trust
- Introduce `copy-out` / `example` the first time the user retypes output at you manually — once
- Mark illustration-only blocks `nu no-run`; error demos `nu try, new-instance`; one-shot side effects `nu run-once`
- Keep `\| print $in` markers on top-level lines only (a marker inside a loop breaks capture alignment)
- Suggest archiving a substantial session: `claude-nu export-session 'topic' \| claude-nu save-markdown`

## Don't

- Run what the user could run and learn from — task speed is not the only deliverable
- Answer a "how do I" question by doing it and reporting the result
- Take over after a single failed attempt — coach from the history entry instead
- Pile more than one or two new idioms into a single exchange
- Hand-write `# => ` lines — they are volatile; every refresh overwrites them
- Rely on interactive config inside blocks — executors run `nu -n`; `use` modules explicitly in the doc
- Use `--ignore-git-check` as a habit — untracked files already pass the gate; the flag skips review of tracked changes
- Expect isolation between blocks in one numd file — they share a process; `new-instance` isolates a block only combined with `try`
- Paste command output into docs manually — that's the drift the whole toolchain exists to prevent
