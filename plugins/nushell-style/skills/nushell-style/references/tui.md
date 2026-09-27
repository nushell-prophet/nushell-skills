# `tui`: Terminal Interfaces from a Pipeline

Nushell 0.116 added the `tui` command family ([#19025](https://github.com/nushell/nushell/pull/19025)).
It builds a picker, a small form or a multi-pane browser from a pipeline, with no Rust project.
Everything below was checked against Nushell 0.116.0.

## When to use it

- A single pick from a list: `input list --fuzzy` is still simpler.
- A pick with a preview, a form with several fields, panes, tabs, a live log: `tui`.
- A full application with its own state machine: still a Ratatui project.

## The model

- Builders (`tui table`, `tui split`, `tui textbox`, …) each append a widget to a `tui` value and pass it on.
- `tui run` shows it on the alternate screen and blocks until the user submits or quits.
- `tui debug` paints the same value into a string, with no terminal, and can replay keys first.
- Both return one record: `{action, focused, selected, page, values, rows, live}`.
  - `action` is `submit` or `quit` (`tui debug` also gives `render` when the keys ended without either).
  - `selected` is the focused widget's selection: a table row, the checked rows with `--multi`, a text box's text, a button's label.
  - `values` holds the state of every widget by id: `values.table-0.index`, `values.name` for `tui textbox --id name`.
- `tui debug` adds `screen`, `widgets` (the tree with each `rect`), `focus` (`{order, default}`) and `pages`.

```nushell
ls | tui label --title "files" | tui table | tui run | get selected.name
tui textbox --id name | tui run | get values.name
```

## Commands

- `tui label` — static text; `--title` goes to the top bar, `--status` to the bottom bar; a closure follows the highlighted row
- `tui menu [items]` — menu bar; entries are strings or `{name, items?, action?}`; `&` marks the mnemonic
- `tui textbox` — editable field; `--placeholder`, `--value`
- `tui table` — navigable rows; `--columns`, `--multi`, `--index`, `--capture-keys`, `--on-select`
- `tui select [items]` — radio list, checkbox list with `--multi`; `--display` like `input list --display`
- `tui button label hook?` — runs the hook, or submits its label when there is none
- `tui progress` — gauge from `--value`, the data, or a `--from` row; values above 1 are read out of `--total`
- `tui log` — append-only view that follows the tail of a stream; `--max-lines`
- `tui tree` — nested records, or a directory walk with `--walk`
- `tui search` — filters the lists in its scope; `--bind /`, `--fuzzy`, `--case-sensitive`, `--columns`
- `tui preview` — text for the highlighted row: a file by default, or what a closure returns
- `tui split [children]` — panes; `--vertical`, `--sizes`, `--ratio`
- `tui box title [children]` — titled, bordered group
- `tui tab title [children]` — a page in the tab bar
- `tui bind key hook` — a key that works anywhere
- `tui run hook?` — the event loop; `--dialog`, `--size`, `--refresh`, `--no-mouse`
- `tui debug hook?` — the headless render; `--keys`, `--until`, `--size`, `--dialog`

Every widget takes `--id` and `--focus`.
The list widgets, `tui label`, `tui log` and `tui progress` also take `--data` and `--from`; `tui preview` takes `--from`.

## Layout

- Widgets in the outer pipeline stack top to bottom, one row each.
- Adjacent `tui button`s are the exception: they share one row, left to right.
- `tui split`, `tui box` and `tui tab` take a list of child widgets, each built in parentheses.
- Chrome — `tui label --title`, `tui label --status`, `tui menu` — goes in the outer pipeline only and stays visible on every page.
- `tui tab` is outer-pipeline only and cannot nest; for a titled group inside a split use `tui box`.
- `tui search` works in both places, and its position is its scope: in the outer pipeline it filters every list, inside a container only that container's lists.

```nushell
ls
| tui label --title "files"
| tui split --sizes [60% 1fr] [
    (tui box "list" [ (tui search --bind /) (tui table --columns [name type size]) ])
    (tui preview { nu-highlight })
  ]
| tui label --status "enter: pick  /: filter  q: quit"
| tui run
```

`--sizes` takes one entry per child: an int is cells (`30`), `"30%"` a share of the split, `"1fr"` a share of what is left, `"min:10"` and `"max:40"` bounds.
Missing entries are `1fr`; `--ratio 60` means `--sizes [60% 1fr]`.

### Ids

- Auto ids number the widgets of each kind in tree order: `table-0`, `table-1`, `search-0`.
- When two children both contain a `table-0`, the second is renumbered `table-1`, and a `--from table-0` inside that child follows it.
- An explicit `--id` is never renumbered; the same explicit id twice is an error.
- Pass `--id` whenever something reads the widget by name: a `--from`, or `values.<id>` in the result.
  `tui debug | get widgets` shows the resolved ids.
- Default focus is the first focusable widget; `--focus` moves it (`tui debug | get focus.default` shows which).

## Data flow

Each widget shows the first of these that exists:

1. its own `--data`, or the value piped into it inside a child list (`[(ls | tui table)]`);
2. what its `--from` source produced;
3. the data of the nearest container above it;
4. the outer pipeline's data.

```nushell
ls | tui split [ (tui table) (tui tree) ] | tui run            # both read ls
tui split [ (ps | tui table) (ls | tui table) ] | tui run       # each has its own rows
tui split [ (tui table --data (ps)) (tui table --data (ls)) ] | tui run  # the same, spelled out
```

- An external command's output (`tail -f log`, `^journalctl --follow`) stays live: the builder returns at once and rows appear as they come.
- A bare unbounded range (`1..`) stays live too.
- A Nushell stream (`ls`, `each`, `generate`) is collected until it ends or reaches 100k rows; only the rest after 100k stays live, as `help tui` says.
  A fast endless one goes live within a moment, but a slow endless one — `1.. | each {|n| sleep 100ms; $n }` — blocks the builder for hours and nothing is painted.
  The 0.116 release notes promise a quarter-second cut-off and `help tui log` shows exactly that slow example; the code (`crates/nu-tui/src/stream.rs`) has neither.
  For a slow live feed, produce it with an external command.
- A child list only holds collected values, so keep an endless producer in the outer pipeline.
- A streamed table keeps its newest 10,000 rows.
- When the TUI closes, a still-running external command is stopped.

`--from <id>` makes a widget follow the highlighted row of a table, tree or select, with a closure over that row:

```nushell
ls | tui split [(tui tree --walk) (tui table --from tree-0 {|node| ls $node.name })] | tui run
ls | tui table | tui label {|row| $"size: ($row.size)" } | tui run
$env.config.keybindings | tui split [(tui table) (tui preview {|row| $row.event | to nuon })] | tui run
```

`tui preview` reads its closure by arity: no parameter transforms the file text (`$in`), one parameter gets the row and nothing is read from disk.

## Hooks

One contract covers every closure that reacts to the user: `tui bind`, menu `action`s, `tui button`, `--on-select`, and the `tui run` / `tui debug` closure.
The hook gets the state record (the same one `tui run` returns) as `$in`, and as its first parameter when it declares one.
Its output decides what happens:

- nothing — nothing changes
- `{action: submit, selected: ...}` — the TUI closes with that selection
- `{action: quit}` — the TUI closes without one
- anything else — it replaces the shared data list, and every widget reading it redraws

```nushell
ls
| tui table
| tui bind ctrl+r {|| ls }                                              # reload
| tui bind s {|state| {action: submit, selected: $state.selected.name} } # submit the name
| tui run

ls | tui table | tui run --dialog --refresh 1sec { ls }                  # re-run the hook every second
tui textbox --id name | tui button Save {|s| $s.values.name | save name.txt; {action: quit} } | tui run
```

- A key is a chord string (`ctrl+s`, `alt+r`, `f5`, `x`) or a reedline record `{modifier: control, keycode: char_s}`.
- Binds win over the built-in keys, except Ctrl+C.
  A bind with no modifier does not fire while typing in a search or text box.
- A menu item without an `action` submits `{menu, item, row}`, where `row` is the highlighted row.

## Testing and agent use: `tui debug`

`tui run` needs a real terminal.
Without one (the Bash tool, a script in CI) it fails with `nu::shell::io::uncategorized_error`.
So build and check the interface with `tui debug`, then hand the user the same pipeline ending in `tui run`.
Both take the same input, so only the last command changes.

```nushell
[{name: a} {name: b}] | tui table | tui debug --keys [down enter] | select action selected
# => {action: submit, selected: {name: b}}

[{name: alpha} {name: beta}] | tui search --bind / | tui table | tui debug --keys "/,type:be,tab,enter" | get selected.name
# => beta

tui label "Delete everything?" | tui button Yes | tui button No | tui debug --keys [tab enter] | get selected
# => No

[a b c] | tui table | tui debug --keys [down down down] --until {|s| $s.values.table-0.index == 1 } | get values.table-0.index
# => 1

{a: {b: 1, c: 2}, d: [3, 4]} | tui tree | tui debug --size [30 5] | get screen
# => ┌ tree (2) ──────────────────┐
# => │▸ a                         │
# => │▸ d                         │
# => │                            │
# => └────────────────────────────┘
```

- `--keys` takes a list or a comma-separated string of tokens: `enter`, `esc`, `tab`, `shift+tab`, arrows, `home`, `end`, `pageup`, `pagedown`, `backspace`, `delete`, `space`, `ctrl+c`, `alt+a`, `f1`, one character, `type:hello`, `click:COL,ROW`, `drag:COL,ROW`, `scroll-up`, `scroll-down`.
- `--size [w h]` sets the canvas (default `[80 24]`); `--dialog` paints the popup frame.
- A live stream is read for up to 5 seconds before painting; a hook closure runs once.
- `get widgets` answers "why does it look like this": each widget's `rect`, a table's `resolved_columns` and filtered `rows`, a search's `query`, the `source` a `--from` widget follows.

## Pitfalls

- A hook error goes to the status bar as `error:<msg>` and the TUI stays open.
  With no `tui label --status` there is no status bar, so the error is not shown anywhere.
  Add a status label while developing hooks.
- `q` quits only when no text field has focus; inside a search or text box it is a character, and Esc leaves the field first.
- Enter on a text box submits the whole TUI with the text as `selected`; to read several fields, take `values` from the result instead.

## Colors

`$env.config.tui` holds the styles (`config nu --doc` documents them):
`border`, `border_focused`, `highlight`, `selected`, `status_bar`, `button`, `title_bar`, `muted`, `progress`, `tab_inactive`, `tab_active`, `header`.

```nushell
$env.config.tui.highlight = {fg: magenta, attr: b}
```
