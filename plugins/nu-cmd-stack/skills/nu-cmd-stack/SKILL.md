---
name: nu-cmd-stack
description: This skill should be used when you are about to hand the user commands to run in their interactive Nushell shell — instead of a code block for them to copy, write the commands as a cmd-stack file that the user loads with `cmd-stack load`, and later read whether they ran and with what exit status. Relevant when a command needs the user's own REPL, their eyes, or their hands; when you give the user a sequence of commands; when the user says "put it in cmd-stack", "положи в стек", "дай команды"; or when the user says "done", "ran it", "выполнил" about commands you handed over.
---

# Hand commands to the user as a cmd-stack file

The user runs commands in an interactive Nushell shell, often in another zellij pane.
A command copied from the chat breaks on wrapped lines and indents,
and `!` in Claude Code runs bash, not Nushell.
So write the commands to a stack file:
the user loads it with `cmd-stack load <Tab>` when ready,
and runs the commands one by one with `ctrl+alt+k` and Enter.

Use it where the user has nu-cmd-stack with `cmd-stack load`;
in cozy, the module is `~/repos/nu-cmd-stack/cmd-stack`.
A command for another machine — for example, the host of a container — goes as a code block.

## Write the file

The folder is `$env.CMD_STACK_DIR`, or `~/.local/share/nushell/cmd-stacks/` when it is not set.
Name the file by time and topic, `20261104-1530-check-the-branch.nu`:
completion shows the newest file first.

The file is a Nushell script:

- The first block, of only comments, describes the stack; completion shows its first line.
- Then one block per command, and one empty line between blocks.
- A `# ...` line on top of a command says what it does: the user sees it in the prompt.
- No empty line inside a command: it splits the command in two.
- Complete commands, with no placeholders: each runs as written.

```nu
# check the branch before landing

# what is not committed
git status --short

# the last three commits
git log -3 --format="%h %s"
```

Write it with the Write tool, so that no quote needs an escape.
Check that it parses, in cozy with
`nu --config ~/.config/nushell/autoload/modules-core.nu --commands 'dotnu diagnose <file> | to nuon'`:
an empty list means no errors.
Then give the user the command to load it: `cmd-stack load 20261104-1530-check-the-branch`.

## Read the outcome

When the user says the commands ran:

```bash
nu --commands 'use ~/repos/nu-cmd-stack/cmd-stack; cmd-stack runs 20261104-1530-check-the-branch | to nuon --pretty'
```

- There is one row for each command that a shell showed; `index` counts the commands, not the description.
- `ran` is the history row that the shell ran after it showed the command.
  When `ran` differs from `command`, the user edited the command or ran a different one.
- `ran: null` means the shell showed the command, but ran nothing after it yet.
- `exit_status` and `duration` come from the history; the output does not.
  For the output, read the screen of the pane where it ran:
  `zellij action dump-screen --pane-id <pane> --full`.
  The dump holds only the lines that the pane still keeps.
