# Regex Flavor: fancy-regex

Nushell's built-in regex engine is [`fancy-regex`](https://docs.rs/fancy-regex) (0.18 as of Nushell 0.114), **not** the Rust `regex` crate. Nushell switched in 0.67 ([#6227](https://github.com/nushell/nushell/pull/6227)) and has stayed on it since.

This matters because most "Rust regex" advice says lookaround and backreferences are impossible. In Nushell they work. fancy-regex is a superset: it hands plain patterns to the `regex` crate and runs a backtracking engine only for the extra features.

## Features you can use (that plain Rust `regex` rejects)

| Feature | Pattern | Matches |
|---|---|---|
| Lookahead | `foo(?=bar)` | `foo` in `foobar`, not in `foobaz` |
| Negative lookahead | `foo(?!bar)` | `foo` in `foobaz` |
| Lookbehind | `(?<=hello )world` | `world` after `hello ` |
| Negative lookbehind | `(?<!foo)bar` | `bar` in `xbar` |
| Variable-length lookbehind | `(?<=a+)b`, `(?<=x\|yy)b` | works — not limited to fixed width |
| Backreference | `(abc)\1` | `abcabc` |
| Named backreference | `(?<p>ab)\k<p>` | `abab` |
| Atomic group | `(?>a*)ab` | nothing in `aaab` — no backtracking inside |
| Possessive quantifier | `a++b` | `aaab` |
| Conditional | `(a)?(?(1)b\|c)` | `ab` |
| Keep-out | `foo\Kbar` | match starts after `foo` |
| Recursion | `\((?:[^()]\|(?R))*\)` | balanced parens |

Everything from the `regex` crate still works: inline flags `(?i)` `(?s)` `(?m)` `(?x)`, unicode classes `\p{Lu}`, named captures in both `(?<name>…)` and `(?P<name>…)` spellings.

```nushell
# Filter a list to lines that do NOT start with a comment, without `not (...)`
$lines | where $it =~ '^(?!\s*#)'

# Rename only the second field, using a lookbehind instead of a capture + rebuild
'a:b:c' | str replace --regex '(?<=a:)b' 'B'   # => a:B:c

# Deduplicate a doubled word
$text | str replace --all --regex '\b(\w+) \1\b' '$1'
```

## Where the fancy engine applies

`=~` / `!~` (and their `like` / `not-like` aliases), `where` with those operators, and every `--regex` flag in the core commands:

`find --regex`, `parse --regex`, `split row --regex`, `split column --regex`, `split list --regex`, `str replace --regex`.

`str escape-regex` escapes a literal string for all of the above — use it whenever a pattern is built from user input or a file path.

## Exception: `idx search --regex`

`idx search` (the built-in indexed grep, 0.113+) runs on the ripgrep engine (`fff-search` → the `regex` crate), **not** fancy-regex. Lookaround and backreferences there match nothing — and fail **silently**, with no error:

```nushell
idx search --regex 'foo\w+'      # => hits
idx search --regex 'foo(?=bar)'  # => [] even when foobar is indexed
```

If you need lookaround over indexed files, filter afterwards with `where line =~ '…'`.

## Cost note

Plain patterns keep the `regex` crate's linear-time guarantee. A pattern using lookaround, backreferences, or recursion drops to backtracking, so its worst case is exponential in the input length. Fine for lines and filenames; think twice before pointing one at a multi-megabyte string.

## Errors

An invalid pattern is a **runtime** error, not a parse error — `nu --ide-check` / `dotnu diagnose` will not catch it. The message can be terse (`Unsupported input` for `(?<`), so test a new pattern against a sample before wiring it into a script.
