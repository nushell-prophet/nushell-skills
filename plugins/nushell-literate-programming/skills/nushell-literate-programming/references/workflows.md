# Everyday literate workflows

Concrete flows, assembled from real usage in this environment. Each starts at the terminal and ends with a git-diffable artifact.

## 1. Explore, then keep it — five capture routes

The session is the raw material. Pick the route by how the exploration happened:

| Route | When | Result |
|---|---|---|
| `numd capture start notes.md` … `numd capture stop` | You know *in advance* the session is worth keeping | Markdown with every command + output, already a numd doc |
| `pipeline \| dotnu embed-add` | One pipeline at a time turns out to be worth keeping | Appends command + output to a growing `.nu` capture file |
| `copy-out 3` | The interesting thing *already happened*, nothing was set up | Clipboard snippet with `# =>` output, from Zellij scrollback |
| `pipeline \| example` | You want to *share* the last command as a runnable snippet | Clipboard: `nu -c '...'` wrap + `# =>` output |
| `hist-to-script` | Reconstruct a whole session after the fact | Bare `.nu` file of the session's commands |

The convention that unifies them: output lives in `# => ` comments. Every capture is immediately valid input for the refresh tools.

## 2. Promote a capture into a document

```nushell
# 1. prune the capture file, keep the pipelines that matter, add `| print $in` markers
# 2. refresh outputs to prove it still runs clean:
dotnu embeds-update exploration.nu
# 3. lift it to markdown and write the prose between the blocks:
open exploration.nu | dotnu generate-numd | save exploration.md
# 4. from now on the doc is maintained by:
numd run exploration.md
```

Each step is optional — plenty of knowledge lives happily as an annotated `.nu` file and never becomes markdown.

## 3. Keep a README that cannot lie

The pattern used by numd's and dotnu's own READMEs:

- Usage examples are ```` ```nu ```` blocks — `numd run README.md` re-executes them and rewrites the `# =>` lines.
- Command-reference sections are generate-regions around `numd doc`:

  ```markdown
  <!-- numd-gen: use dotnu; numd doc 'dotnu embeds-update' -->
  ```

  so docs regenerate from live signatures, `@example` attributes included.
- Illustration-only blocks are fenced `nu no-run`; blocks that demonstrate errors are `nu try, new-instance`.

The maintenance loop is three commands:

```nushell
git commit -am 'readme edits'   # numd refuses to run over uncommitted changes anyway
numd run README.md
git diff                        # only genuine behavior changes show up
```

If the diff is empty, the docs are proven current. If it isn't, either the code changed (update the prose) or the doc caught a regression (fix the code). Both outcomes are wins — this is documentation as a test suite.

## 4. Pin external facts, diff the world

Any fact about the environment can be captured once and re-verified forever:

```nushell
# dotnu-captures/nu--help.nu
nu --help | print $in
# => ...
```

```nushell
# after an upgrade:
glob dotnu-captures/*.nu | each { dotnu embeds-update $in }
git diff   # exactly what changed in the outside world
```

Same shape for `@example` results (`dotnu examples-update module.nu`) and for whole tutorial documents (`numd run docs/*.md`). The rhythm is always: **commit → refresh → read the diff**.

## 5. The AI-companion loop

For an agent working alongside the user, literate tooling changes what "explaining" means — instead of describing what a command does, produce a document that proves it:

- **Answer with a runnable doc.** Write the explanation as markdown with `nu` blocks, then `numd run answer.md --echo` to verify every claim before showing it. Wrong output = wrong explanation, caught before the user sees it.
- **Preview, never clobber.** `--echo` and `--dry-run` first; the in-place run only on committed files. numd's git gate enforces this, honor it rather than reaching for `--ignore-git-check`.
- **Respect the clean environment.** Blocks run under `nu -n`: `use` the modules a block needs inside the doc itself. That is a feature — the doc then works for any reader, not just this machine.
- **Archive decisions.** After a substantial session: `claude-nu export-session 'topic' | claude-nu save-markdown` — the conversation lands in `docs/sessions/` where git preserves the reasoning. Before re-solving a problem, `claude-nu -f 'topic'` to check whether a past session already solved it.
- **Teach through captures.** When the user asks "what did that do?", `copy-out` or `example` the exchange and annotate it — the snippet is already in the shared `# =>` dialect.

## 6. Debugging and profiling, literate-style

```nushell
dotnu set-x slow-script.nu          # instrumented copy: each block echoed and timed
source slow-script_setx.nu          # watch where the seconds go

dotnu extract-module-command dotnu/ embeds-update --vars --output /tmp/dbg.nu
# edit the let-bindings between #dotnu-vars-start/-end, then:
source /tmp/dbg.nu                  # run a module command's body as a flat script

debug profile --spans { expensive-pipeline } | format profile   # nu-goodies: span tree with bars
```

## 7. Module hygiene as one-liners

```nushell
dotnu list-module-exports mod.nu          # what does this module actually export?
dotnu list-module-interface toolkit.nu    # what can I call after `use`?

# which commands does no test reach?
glob my-module/*.nu | append (glob tests/*.nu)
| dotnu dependencies ...$in
| dotnu filter-commands-with-no-tests

# self-maintaining mod.nu re-export list:
#** ls *.nu | where name != 'mod.nu' | get name | each { $"export use ($in) *" } | to text
#**end
# refresh with: dotnu expand-code mod.nu
```
