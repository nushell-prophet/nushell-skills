# Development convenience commands for the nushell-skills marketplace.
# These are NOT part of the distributed plugins — they help maintain skill content.

const skills_global_dir = '~/.claude/skills'
const managed_skills = ['nushell-style' 'nushell-completions']

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

# Copy skills from ~/.claude/skills into plugin directories
@example "Vendor all skills" { nu toolkit.nu vendor }
@example "Vendor without committing" { nu toolkit.nu vendor --no-commit }
export def 'main vendor' [
    --no-commit # Skip creating a git commit after copying
] {
    let global_dir = $skills_global_dir | path expand
    mut total_files = 0

    for skill in $managed_skills {
        let source = $"($global_dir)/($skill)"
        let dest = skill-plugin-dir $skill

        if not ($source | path exists) {
            print $"(ansi yellow)⚠(ansi reset) ($skill): not found at ($source)"
            continue
        }

        if ($dest | path exists) { rm -rf $dest }
        mkdir $dest
        cp -r ($"($source)/*" | into glob) $dest
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
            git commit -m $"chore: vendor skills \(($date)\)"
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
] {
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

        if ($dest | path exists) { rm -rf $dest }
        cp -r $source $dest
        let file_count = glob $"($dest)/**/*" | where ($it | path type) == 'file' | length
        print $"(ansi green)✓(ansi reset) ($skill) \(($file_count) files\)"
        $total_files = $total_files + $file_count
    }

    print $"\n(ansi attr_dimmed)Installed ($total_files) files to ($global_dir)(ansi reset)"
    print $"(ansi green)✓(ansi reset) Skills ready at (ansi cyan)($global_dir)(ansi reset)"
}
