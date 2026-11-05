# Development convenience commands for the nushell-skills marketplace.
# These are NOT part of the distributed plugins — they help maintain skill content.

const skills_global_dir = '~/.claude/skills'
const managed_skills = ['nushell-style' 'nushell-completions' 'nushell-history' 'nushell-literate-programming' 'claude-nu' 'nu-cmd-stack']

const repo_dir = path self | path dirname

# Strings that name the machine of the maintainer or his mono workflow.
# Why: every exported file reaches a public reader, and a plugin file also reaches
# the agent of every user who installs it.
const private_strings = ['/Users/' 'ai-sandbox-dev-container' 'wtr/' 'mono-land']

# The files that `check` skips: the `exclude` of this repo in mono.yml, which never reach
# the recipient; this file, which holds the strings themselves; and nushell-release-fold.
# Not read from mono.yml because: this file ships to the recipient, which has no mono.yml.
# Why nushell-release-fold: the maintainer keeps it published as it is; it is the release
# workflow of this repo in the mono, and the plugin system never installs `.claude/skills/`.
const skipped = [
    ':!todo'
    ':!CLAUDE.local.md'
    ':!.claude/settings.json'
    ':!.claude/memory'
    ':!toolkit.nu'
    ':!.claude/skills/nushell-release-fold'
]

# Check if a path has uncommitted changes in its git repository
def has-uncommitted-changes [path: path]: nothing -> bool {
    if not ($path | path exists) { return false }

    let dir = if ($path | path type) == 'dir' { $path } else { $path | path dirname }

    let git_check = do { cd $dir; ^git rev-parse --git-dir } | complete

    if $git_check.exit_code != 0 { return false }

    let status = do { cd $dir; ^git status --porcelain -- $path } | complete

    ($status.stdout | str trim | is-not-empty)
}

# Resolve the plugin skill directory for a given skill name
def skill-plugin-dir [skill: string]: nothing -> string {
    $"plugins/($skill)/skills/($skill)"
}

export def main [] { }

# Stop when a file that the export publishes names the machine of the maintainer or his mono workflow.
# `gate` in mono.yml runs it before every export and every `/mono-land`.
@example "Check the files on disk" { nu toolkit.nu check }
@example "Check a commit" { nu toolkit.nu check --rev HEAD }
export def 'main check' [
    --rev: string # check this commit instead of the files on disk
]: nothing -> nothing {
    let patterns = $private_strings | each {|s| ['-e' $s] } | flatten
    let tree = if $rev == null { [] } else { [$rev] }
    let found = ^git -C $repo_dir grep --line-number --fixed-strings ...$patterns ...$tree -- . ...$skipped | complete

    match $found.exit_code {
        0 => {
            let lines = $found.stdout | lines
            let hits = if $rev == null { $lines } else { $lines | str replace $"($rev):" '' }

            error make --unspanned {
                msg: 'an exported file names the machine of the maintainer or his mono workflow'
                help: ($hits | str join (char nl))
            }
        }
        1 => null
        _ => { error make --unspanned {msg: ($found.stderr | str trim)} }
    }
}

# Copy skills from ~/.claude/skills into plugin directories
@example "Vendor all skills" { nu toolkit.nu vendor }
@example "Vendor without committing" { nu toolkit.nu vendor --no-commit }
export def 'main vendor' [
    --no-commit # Skip creating a git commit after copying
]: nothing -> nothing {
    let global_dir = $skills_global_dir | path expand
    mut total_files = 0

    for skill in $managed_skills {
        let source = $"($global_dir)/($skill)"
        let dest = skill-plugin-dir $skill

        if not ($source | path exists) {
            print $"(ansi yellow)⚠(ansi reset) ($skill): not found at ($source)"
            continue
        }

        if ($dest | path exists) { rm --recursive --force $dest }
        mkdir $dest
        cp --recursive ($"($source)/*" | into glob) $dest
        let file_count = glob $"($dest)/**/*" | where ($it | path type) == 'file' | length

        print $"(ansi green)✓(ansi reset) ($skill) \(($file_count) files\)"
        $total_files = $total_files + $file_count
    }

    print $"\n(ansi attr_dimmed)Copied ($total_files) files from ($global_dir)(ansi reset)"

    if not $no_commit {
        let status = git status --porcelain plugins/ | str trim

        if $status != "" {
            git add plugins/
            let date = date now | format date "%Y-%m-%d"

            git commit --message $"chore: vendor skills \(($date)\)"
            print $"(ansi green)Committed skill updates(ansi reset)"
        } else {
            print $"(ansi attr_dimmed)No changes to commit(ansi reset)"
        }
    }
}

# Copy skills from plugin directories to ~/.claude/skills (for local testing)
@example "Install skills locally" { nu toolkit.nu install-locally }
@example "Force overwrite" { nu toolkit.nu install-locally --force }
export def 'main install-locally' [
    --force # Overwrite even if destination has uncommitted changes
]: nothing -> nothing {
    let global_dir = $skills_global_dir | path expand

    if not $force {
        let dirty = $managed_skills
            | each { $"($global_dir)/($in)" }
            | where { has-uncommitted-changes $in }

        if ($dirty | is-not-empty) {
            print $"(ansi yellow)⚠(ansi reset) Uncommitted changes in destination:"
            $dirty | each { print $"  ($in)" }
            print $"\n  Use (ansi cyan)--force(ansi reset) to overwrite"
            return
        }
    }

    mut total_files = 0

    for skill in $managed_skills {
        let source = skill-plugin-dir $skill
        let dest = $"($global_dir)/($skill)"

        if not ($source | path exists) {
            print $"(ansi yellow)⚠(ansi reset) ($skill): not found at ($source)"
            continue
        }

        if ($dest | path exists) { rm --recursive --force $dest }
        cp --recursive $source $dest
        let file_count = glob $"($dest)/**/*" | where ($it | path type) == 'file' | length

        print $"(ansi green)✓(ansi reset) ($skill) \(($file_count) files\)"
        $total_files = $total_files + $file_count
    }

    # Why: nushell-style ships the nushell-reviewer agent, and a local install
    # without it would test the skill apart from the agent that loads it.
    let agents_dir = '~/.claude/agents' | path expand

    for agent in (glob 'plugins/*/agents/*.md') {
        mkdir $agents_dir
        cp $agent $agents_dir
        print $"(ansi green)✓(ansi reset) agents/($agent | path basename)"
    }

    print $"\n(ansi attr_dimmed)Installed ($total_files) files to ($global_dir)(ansi reset)"
    print $"(ansi green)✓(ansi reset) Skills ready at (ansi cyan)($global_dir)(ansi reset)"
}
