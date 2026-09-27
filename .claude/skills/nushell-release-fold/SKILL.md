---
name: nushell-release-fold
description: Fold a new Nushell release into the skills of this repo — read the release notes, verify every claim against the new binary, update the migration and enhancements references and the other affected skills, bump the versions. Use when the user says "new nushell release", "nushell 0.116 is out", "nushell 0.115.2 is out", "fold in 0.116", "update the skills for the new nushell", "обнови скиллы под новый релиз". Maintainer-only: works on this repo's plugins/, not on user code — for migrating a user's scripts, `nushell-style` (references/migration.md) is the right one.
---

# Fold a Nushell release into the skills

A skill that teaches a stale Nushell is worse than no skill: the agent states the old behavior with full confidence.
Before starting, find the previous fold-in in git history: `git log --grep='fold Nushell' main` for the landed commit, `git tag --list 'archive/nushell-*'` for its per-step history.
Read its message: it records what verification caught that reading alone missed.

## 1. Get the sources current

- Refresh the docs: `cozy docs nushell --output-dir ../nushell-docs`.
  Without the flag it works on `./nushell-docs`, so run from this repo it clones a second copy here instead of updating the sibling.
  Then check the release note is there: `ls ../nushell-docs/blog | where name =~ 'nushell_v0_<minor>'`.
  If it is missing, stop and say so — do not fetch the web instead.
- The full Nushell repo is `../upstream-big-repos/nushell/`; command signatures (`crates/nu-command/`) and std (`crates/nu-std/std/`) live there, not in the notes.
  `git -C ../upstream-big-repos/nushell fetch --tags`, then read the release as tagged — `git grep <pattern> 0.<minor>.0`, `git show 0.<minor>.0:<path>` — without switching the user's checkout.
- Check the binary: `nu --version` must print the new release.
  If it is older, stop: every claim below is verified by running it, and an old binary verifies nothing.
- Check that the binary has the features the release touches: `nu --help | find mcp`.
  The 0.116 build on `PATH` came without default features, so `--mcp` did not exist; build one from `git archive 0.<minor>.0` for those checks.
- Keep the previous release's binary for before/after runs (`/home/linuxbrew/.linuxbrew/Cellar/nushell/<old>/bin/nu` in the sandbox).
  In the 0.116 run only the comparison showed that `--compact-list-indent` never changed anything, that 0.115 `finally` was worse than its note said, and that `"1,500" | into float` silently turned from an error into `1.5`.

## 2. Sort the release note

Read the whole note, and every patch release note since the last fold-in (`0.<minor>.1`, …).
List them first: `ls ../nushell-docs/blog | where name =~ 'nushell_v0_'` and take every file newer than the last folded version.
Do not skip patch releases: the user notes that sometimes they are the real release.
No patch release had been folded in up to 0.115, so check the patches of the previous minor too.
A patch release alone is reason enough to run this skill; `nushell-style` then gets `1.<minor>.<n+1>`.
Put each item in one bucket:

- a break (a removed or renamed command, a changed default, a new parse error) → `references/migration.md`
- a new feature that improves existing scripts → `references/enhancements.md`
- something that changes an existing rule in another reference (`regex.md`, `mcp.md`, `nuon.md`, `testing.md`, …) → that file
- a completion change → the `nushell-completions` skill
- a break that bites often → also a one-line pointer in `nushell-style/SKILL.md`, since that file always loads and a reference may not
- nothing an agent writing Nushell would do differently → drop it

For a large release, hand the buckets to agents, one agent per file so none collide.
Agents edit only: no `git add`, `git commit` or `git switch` — you commit.
Each brief says to run every example on the new binary and to mark what could not be checked as ASSUMED in the report.
Finish with one more agent whose brief is a verification sweep, not a writing assignment.
Also check `git log` before each commit: another session may be committing to the same branch (in the 0.116 run a parallel session added `tui.md`).

## 3. Verify every claim by running it

Execute each example against the new binary before writing it down, in a fresh process (`nu -c`, or a script), not a long-lived MCP session.
The registered MCP server can run an older `nu` than the one on `PATH`: during the 0.115 run it was still 0.114.1.
Release-note prose is sometimes imprecise; when the note and the source at the release tag disagree, the source wins.
In the 0.115 run this caught a wrong record shape in the notes, a release-note example that does not parse, and a variable that is empty under `nu -c` and MCP.
A claim you could not run is not written.

A bug found this way belongs upstream too, not only worked around in the skill.
Report it and propose the fix where it lives: a wrong release-note or book example → a branch in `../upstream-big-repos/nushell.github.io/`; a bug in Nushell itself → a branch in `../upstream-big-repos/nushell/`, made from a freshly fetched upstream head.
Make each branch with `git worktree add ../worktrees/<name> -b <name> <upstream>/main`, so the user's checkout and its local changes stay untouched.
If a checkout fails on a corrupt object in a file the fix does not need (the 0.116 run hit a broken `.gif` in nushell.github.io), use `--no-checkout` plus `git sparse-checkout set --no-cone /<path>`, and report the corruption instead of repairing it.
Do not push or open a PR — that step is the user's.

## 4. Edit in place, not by appending

When the release changes something an earlier release introduced, rewrite that section.
Appending leaves the file contradicting itself.
Remove lines about commands that no longer exist.

Then sweep every file of every skill for examples the release broke, not only `migration.md` and `enhancements.md`.
After 0.114, `patterns.md`, `formatting.md` and `SKILL.md` still taught `scan --noinit`, `str upcase` and `$e.json`, and none of them failed loudly.
Fix older text that is wrong or weak while you are there: earlier models wrote these skills, and the user wants them improved, not only extended.

Edit in `plugins/`, then `nu toolkit.nu install-locally` to test (see `CLAUDE.md`).

## 5. Update the version range everywhere

The covered range (`0.100–0.<minor>`) is written in several places; update all of them:

- `nushell-style/SKILL.md`: the `description` and the lines pointing at `migration.md` and `enhancements.md`
- the headings of `migration.md` and `enhancements.md`
- the file tree in this repo's `CLAUDE.md`

`rg '0\.100' --glob '*.md'` finds them.

## 6. Bump versions

- `nushell-style` tracks Nushell in its minor: `1.<minor>.0`.
- Every other plugin that changed gets its own bump.
- Both `plugins/<name>/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` carry the version.

## 7. Check the always-loaded pitfalls

The pitfalls cheatsheet in `../cozy/docker-files/global-claude.md` loads in every session, whether a skill triggers or not.
Re-run each pitfall that touches a changed area against the new binary.
That file lives in another repo: report what is stale and propose the change there, do not edit it from this task.

## 8. Commit

One commit per bucket on a branch, then land it with `40-land-branch`.
The body says what verification caught and why each placement call went where it did — the 0.115 message is the model.
