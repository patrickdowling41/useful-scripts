#!/usr/bin/env zsh

# wta - Git Worktree Add Helper
# Automates creating a git worktree with branch check, git pull, .env copying, and dependency installation.

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
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
    return 0 2>/dev/null || exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not a git repository" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: wta <branch-name>" >&2
    return 1 2>/dev/null || exit 1
fi

local BRANCH_NAME="$1"
local CURRENT_BRANCH=$(git branch --show-current)

if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
    read "REPLY?You are currently on branch '$CURRENT_BRANCH' (not main). Continue? (y/n) "
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        return 1 2>/dev/null || exit 1
    fi
fi

if git rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
    echo "Pulling latest changes on '$CURRENT_BRANCH'..."
    if ! git pull; then
        echo "Error: git pull failed." >&2
        return 1 2>/dev/null || exit 1
    fi
else
    echo "No upstream tracking branch found for '$CURRENT_BRANCH'; skipping git pull."
fi

local MAIN_WORKTREE="$(git worktree list --porcelain | head -n 1 | sed 's/^worktree //')"
if [ -z "$MAIN_WORKTREE" ]; then
    MAIN_WORKTREE="$(git rev-parse --show-toplevel)"
fi

local PROJECT_NAME=$(basename "$MAIN_WORKTREE")
local WORKTREE_PARENT="$(dirname "$MAIN_WORKTREE")"
local DIR_SUFFIX="${BRANCH_NAME//\//-}"
local WORKTREE_PATH="${WORKTREE_PARENT}/${PROJECT_NAME}-${DIR_SUFFIX}"

echo "Creating worktree at: $WORKTREE_PATH"
echo "Branch: $BRANCH_NAME"

local ADD_STATUS=0
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    echo "Branch '$BRANCH_NAME' already exists. Checking out existing branch..."
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
    ADD_STATUS=$?
else
    echo "Branch '$BRANCH_NAME' does not exist. Creating new branch..."
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
    ADD_STATUS=$?
fi

if [ $ADD_STATUS -eq 0 ]; then
    echo ""
    echo "Successfully created worktree!"

    # Copy .env files from MAIN_WORKTREE to WORKTREE_PATH
    if [ -n "$MAIN_WORKTREE" ] && [ -d "$MAIN_WORKTREE" ] && [ "$MAIN_WORKTREE" != "$WORKTREE_PATH" ]; then
        echo "Copying .env files..."
        find "$MAIN_WORKTREE" \
            \( -name .git \
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
            -o -name .cache-loader \) -prune \
            -o -type f -name ".env" -print | while IFS= read -r env_file; do
                [ -z "$env_file" ] && continue
                rel_path="${env_file#"$MAIN_WORKTREE"/}"
                dest_file="$WORKTREE_PATH/$rel_path"
                dest_dir="$(dirname "$dest_file")"
                if [ ! -f "$dest_file" ]; then
                    mkdir -p "$dest_dir"
                    cp "$env_file" "$dest_file"
                    echo "  Copied $rel_path"
                fi
            done
    fi

    # Install dependencies if this is a Node.js project
    if [ -f "$WORKTREE_PATH/package.json" ]; then
        if [ ! -d "$WORKTREE_PATH/node_modules" ]; then
            local PKG_MANAGER=""

            # 1. Detect from lockfiles
            if [ -f "$WORKTREE_PATH/pnpm-lock.yaml" ]; then
                PKG_MANAGER="pnpm"
            elif [ -f "$WORKTREE_PATH/yarn.lock" ]; then
                PKG_MANAGER="yarn"
            elif [ -f "$WORKTREE_PATH/package-lock.json" ]; then
                PKG_MANAGER="npm"
            elif [ -f "$WORKTREE_PATH/bun.lockb" ] || [ -f "$WORKTREE_PATH/bun.lock" ]; then
                PKG_MANAGER="bun"
            fi

            # 2. If no lockfile, inspect "packageManager" in package.json
            if [ -z "$PKG_MANAGER" ]; then
                local PM_FIELD=$(grep -o '"packageManager"[[:space:]]*:[[:space:]]*"[^"]*"' "$WORKTREE_PATH/package.json" 2>/dev/null | head -n 1 | cut -d'"' -f4)
                if [[ "$PM_FIELD" == pnpm* ]]; then
                    PKG_MANAGER="pnpm"
                elif [[ "$PM_FIELD" == yarn* ]]; then
                    PKG_MANAGER="yarn"
                elif [[ "$PM_FIELD" == npm* ]]; then
                    PKG_MANAGER="npm"
                elif [[ "$PM_FIELD" == bun* ]]; then
                    PKG_MANAGER="bun"
                fi
            fi

            # 3. Fallback: pick the first available package manager in PATH
            if [ -z "$PKG_MANAGER" ]; then
                if command -v pnpm >/dev/null 2>&1; then
                    PKG_MANAGER="pnpm"
                elif command -v yarn >/dev/null 2>&1; then
                    PKG_MANAGER="yarn"
                elif command -v npm >/dev/null 2>&1; then
                    PKG_MANAGER="npm"
                fi
            fi

            # Execute install
            if [ -n "$PKG_MANAGER" ]; then
                if command -v "$PKG_MANAGER" >/dev/null 2>&1; then
                    echo "Installing dependencies with $PKG_MANAGER..."
                    (cd "$WORKTREE_PATH" && "$PKG_MANAGER" install)
                else
                    echo "Warning: Project detected as using '$PKG_MANAGER', but '$PKG_MANAGER' is not in PATH. Skipping dependency installation."
                fi
            fi
        fi
    fi

    echo "Run this to enter: cd \"$WORKTREE_PATH\""
fi
