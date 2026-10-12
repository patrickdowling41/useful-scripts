#!/usr/bin/env fish

# wta - Git Worktree Add Helper (fish implementation)
#
# Fish counterpart of wta.sh. Fish autoloads this file when it is installed as
# wta.fish in a directory on $fish_function_path (see install.sh), so no
# config.fish changes are needed.
#
# Behaviour is intentionally identical to the zsh version in wta.sh: if you
# change one, change the other.

function wta --description 'Create a git worktree with .env copying and dependency install'
    set -l first $argv[1]

    if test "$first" = -h; or test "$first" = --help
        echo "Usage: wta <branch-name>"
        echo ""
        echo "Automates git worktree creation with:"
        echo "  - Current branch check (prompts if not on main or master)"
        echo "  - Pulls latest changes on base branch"
        echo "  - Consistent directory naming: <parent>/<repo>-<branch>"
        echo "  - Checks out existing branch or creates a new one"
        echo "  - Copies .env files from the main worktree (excluding build/cache dirs)"
        echo "  - Detects package manager (pnpm, yarn, npm, bun) and installs dependencies"
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        return 0
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Error: Not a git repository" >&2
        return 1
    end

    if test -z "$first"
        echo "Usage: wta <branch-name>" >&2
        return 1
    end

    set -l BRANCH_NAME $first
    set -l CURRENT_BRANCH (git branch --show-current)

    if test "$CURRENT_BRANCH" != main -a "$CURRENT_BRANCH" != master
        # A failed read (EOF, no tty) leaves REPLY empty and so aborts, which
        # matches the zsh version's effective behaviour.
        read -l -P "You are currently on branch '$CURRENT_BRANCH' (not main). Continue? (y/n) " REPLY
        echo ""
        if not string match -qr '^[Yy]$' -- $REPLY
            echo "Aborted."
            return 1
        end
    end

    if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1
        echo "Pulling latest changes on '$CURRENT_BRANCH'..."
        if not git pull
            echo "Error: git pull failed." >&2
            return 1
        end
    else
        echo "No upstream tracking branch found for '$CURRENT_BRANCH'; skipping git pull."
    end

    set -l MAIN_WORKTREE (git worktree list --porcelain | head -n 1 | sed 's/^worktree //')
    if test -z "$MAIN_WORKTREE"
        set MAIN_WORKTREE (git rev-parse --show-toplevel)
    end

    set -l PROJECT_NAME (basename "$MAIN_WORKTREE")
    set -l WORKTREE_PARENT (dirname "$MAIN_WORKTREE")
    set -l DIR_SUFFIX (string replace -a / - -- $BRANCH_NAME)
    set -l WORKTREE_PATH "$WORKTREE_PARENT/$PROJECT_NAME-$DIR_SUFFIX"

    echo "Creating worktree at: $WORKTREE_PATH"
    echo "Branch: $BRANCH_NAME"

    set -l ADD_STATUS 0
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; or git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"
        echo "Branch '$BRANCH_NAME' already exists. Checking out existing branch..."
        git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
        set ADD_STATUS $status
    else
        echo "Branch '$BRANCH_NAME' does not exist. Creating new branch..."
        git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
        set ADD_STATUS $status
    end

    if test $ADD_STATUS -ne 0
        return $ADD_STATUS
    end

    echo ""
    echo "Successfully created worktree!"

    # Copy .env files from MAIN_WORKTREE to WORKTREE_PATH
    if test -n "$MAIN_WORKTREE" -a -d "$MAIN_WORKTREE" -a "$MAIN_WORKTREE" != "$WORKTREE_PATH"
        echo "Copying .env files..."
        # Prefix length is fixed, so strip it by offset rather than by pattern:
        # every find result starts with "$MAIN_WORKTREE/".
        set -l STRIP_FROM (math (string length -- $MAIN_WORKTREE) + 2)
        find "$MAIN_WORKTREE" \
            "(" -name .git \
            -o -name node_modules \
            -o -name .nx \
            -o -name dist \
            -o -name .dist \
            -o -name tmp \
            -o -name out-tsc \
            -o -name test-output \
            -o -name cdk.out \
            -o -name cdktf.out \
            -o -name build \
            -o -name .docusaurus \
            -o -name .cache-loader ")" -prune \
            -o -type f -name .env -print | while read -l env_file
            test -z "$env_file"; and continue
            set -l rel_path (string sub -s $STRIP_FROM -- $env_file)
            set -l dest_file "$WORKTREE_PATH/$rel_path"
            set -l dest_dir (dirname "$dest_file")
            if not test -f "$dest_file"
                mkdir -p "$dest_dir"
                cp "$env_file" "$dest_file"
                echo "  Copied $rel_path"
            end
        end
    end

    # Install dependencies if this is a Node.js project
    if test -f "$WORKTREE_PATH/package.json"; and not test -d "$WORKTREE_PATH/node_modules"
        set -l PKG_MANAGER ""

        # 1. Detect from lockfiles
        if test -f "$WORKTREE_PATH/pnpm-lock.yaml"
            set PKG_MANAGER pnpm
        else if test -f "$WORKTREE_PATH/yarn.lock"
            set PKG_MANAGER yarn
        else if test -f "$WORKTREE_PATH/package-lock.json"
            set PKG_MANAGER npm
        else if test -f "$WORKTREE_PATH/bun.lockb" -o -f "$WORKTREE_PATH/bun.lock"
            set PKG_MANAGER bun
        end

        # 2. If no lockfile, inspect "packageManager" in package.json
        if test -z "$PKG_MANAGER"
            set -l PM_FIELD (grep -o '"packageManager"[[:space:]]*:[[:space:]]*"[^"]*"' "$WORKTREE_PATH/package.json" 2>/dev/null | head -n 1 | cut -d'"' -f4)
            if string match -q 'pnpm*' -- $PM_FIELD
                set PKG_MANAGER pnpm
            else if string match -q 'yarn*' -- $PM_FIELD
                set PKG_MANAGER yarn
            else if string match -q 'npm*' -- $PM_FIELD
                set PKG_MANAGER npm
            else if string match -q 'bun*' -- $PM_FIELD
                set PKG_MANAGER bun
            end
        end

        # 3. Fallback: pick the first available package manager in PATH
        if test -z "$PKG_MANAGER"
            if command -q pnpm
                set PKG_MANAGER pnpm
            else if command -q yarn
                set PKG_MANAGER yarn
            else if command -q npm
                set PKG_MANAGER npm
            end
        end

        # Execute install
        if test -n "$PKG_MANAGER"
            if command -q $PKG_MANAGER
                echo "Installing dependencies with $PKG_MANAGER..."
                # pushd/popd keeps the caller's directory unchanged, which is
                # what the zsh version's subshell achieves.
                pushd "$WORKTREE_PATH"
                $PKG_MANAGER install
                popd
            else
                echo "Warning: Project detected as using '$PKG_MANAGER', but '$PKG_MANAGER' is not in PATH. Skipping dependency installation."
            end
        end
    end

    echo "Run this to enter: cd \"$WORKTREE_PATH\""
end
