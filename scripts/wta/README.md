# `wta` (Git Worktree Add Helper)

A Zsh shell function that streamlines creating and preparing Git worktrees for feature development and bug fixes.

---

## Overview

When working across multiple tasks or branches, Git worktrees allow you to have multiple branches checked out simultaneously in separate directories without switching branches or stashing uncommitted work in your main directory.

`wta` automates the manual, repetitive steps of creating a worktree:
1. **Safety check**: Checks if you are currently on `main` or `master` (prompts before proceeding if you are on another branch).
2. **Latest base**: Automatically pulls the latest changes on your base branch.
3. **Consistent naming**: Creates the worktree in a sibling directory named `<parent>/<repo-name>-<branch-slug>`.
4. **Branch handling**: Checks out the branch if it already exists (locally or remotely) or creates a new branch.
5. **Environment sync**: Automatically finds and copies `.env` files from the main worktree into the new worktree (skipping build, cache, and dependency directories).
6. **Dependency installation**: Automatically detects whether the repository uses `pnpm`, `yarn`, `npm`, or `bun` (based on lockfiles or `"packageManager"` in `package.json`) and runs the appropriate install command.
7. **Quick access**: Prints the exact `cd` command to jump straight into your new worktree.

---

## Directory Structure

```text
scripts/wta/
├── README.md       # Documentation & setup instructions (this file)
├── wta.sh          # The core shell script & Zsh function source
├── install.sh      # Automated installer for Zsh config & ~/.zshrc
└── uninstall.sh    # Uninstaller script
```

---

## Prerequisites

- **Git** (`git --version`)
- **Zsh** (`zsh --version`) - standard default shell on macOS
- *(Optional)* **Node package manager** (`pnpm`, `yarn`, `npm`, or `bun`) - for automatic dependency installation

---

## Installation

### Method 1: Automated Installation (Recommended)

Run the included `install.sh` script:

```bash
# From the repository root:
./scripts/wta/install.sh

# Or from inside scripts/wta/:
cd scripts/wta && ./install.sh
```

#### What `install.sh` does:
1. Copies `wta` into your custom Zsh functions directory (`~/.config/zsh/functions/wta`).
2. Configures your `~/.zshrc` (if not already configured):
   - Adds `fpath=(~/.config/zsh/functions $fpath)`
   - Adds `autoload -Uz wta`
3. Backs up your `~/.zshrc` before making any modifications.
4. Verifies that `wta` loads properly in Zsh.

#### Developer / Symlink Mode:
If you want edits in this repository to immediately reflect in your shell without re-running the installer, use `--symlink` (or `-s`):

```bash
./scripts/wta/install.sh --symlink
```

#### Installer Options:

| Option | Description |
| :--- | :--- |
| `-s, --symlink` | Symlink `wta` instead of copying |
| `-d, --dest <dir>` | Custom functions destination directory (default: `~/.config/zsh/functions`) |
| `--zshrc <path>` | Custom path to `.zshrc` (default: `~/.zshrc`) |
| `-n, --dry-run` | Preview changes without modifying files |
| `-f, --force` | Overwrite existing files without prompt |
| `-h, --help` | Display help message |

---

### Method 2: Manual Installation

If you prefer to configure your shell manually:

1. **Create the custom functions directory:**
   ```bash
   mkdir -p ~/.config/zsh/functions
   ```

2. **Copy (or symlink) the `wta.sh` script as `wta`:**
   ```bash
   cp scripts/wta/wta.sh ~/.config/zsh/functions/wta
   chmod +x ~/.config/zsh/functions/wta
   ```

3. **Add the following to your `~/.zshrc`:**
   ```zsh
   # Add custom functions directory to Zsh path
   fpath=(~/.config/zsh/functions $fpath)

   # Lazy-load the wta function
   autoload -Uz wta
   ```

4. **Reload your shell:**
   ```bash
   source ~/.zshrc
   ```

---

## Usage

From within any Git repository:

```bash
wta <branch-name>
```

### Examples

#### 1. Create a new feature branch
```bash
wta feature/DI-1234-auth-flow
```
- If current branch is `main`, it runs `git pull`.
- Creates a new branch `feature/DI-1234-auth-flow`.
- Creates a new worktree folder next to your repo: `../<repo-name>-feature-DI-1234-auth-flow`.
- Copies `.env` files from your main repository.
- Auto-detects package manager (`pnpm`, `yarn`, `npm`, `bun`) and runs install.
- Outputs:
  ```text
  Run this to enter: cd "../<repo-name>-feature-DI-1234-auth-flow"
  ```

#### 2. Check out an existing remote branch
```bash
wta bugfix/DI-5678-fix-timeout
```
- If `origin/bugfix/DI-5678-fix-timeout` exists, checks it out into a dedicated worktree folder without creating a duplicate branch.

#### 3. View Help
```bash
wta --help
```

---

## How It Works Under the Hood

```
Your Workspace:
├── my-repo/                         <-- Main repository (on main/master)
│   ├── .git/
│   ├── .env                         <-- Existing secrets/configs
│   ├── apps/
│   └── package.json
│
└── my-repo-feature-DI-1234-auth/     <-- Created by `wta feature/DI-1234-auth`
    ├── .git (worktree pointer)
    ├── .env                         <-- Automatically copied from main
    ├── apps/
    ├── node_modules/                <-- Automatically installed (pnpm, yarn, npm, bun)
    └── package.json
```

### Directory Exclusion for `.env` Copy
When copying `.env` files, `wta` prunes heavy build and dependency directories:
- `.git`
- `node_modules`
- `.nx`
- `dist` and `.dist`
- `tmp`
- `out-tsc`
- `test-output`
- `cdk.out` and `cdktf.out`
- `build`
- `.docusaurus`
- `.cache-loader`

---

## Uninstallation

To remove `wta`:

```bash
./scripts/wta/uninstall.sh
```

To also clean up the autoload line in `~/.zshrc`:

```bash
./scripts/wta/uninstall.sh --clean-zshrc
```

---

## Troubleshooting

### `command not found: wta`
1. Make sure `~/.config/zsh/functions` is in your `fpath` before `autoload -Uz wta`:
   ```bash
   echo $fpath
   ```
2. Reload your `.zshrc`:
   ```bash
   source ~/.zshrc
   ```

### `Error: Not a git repository`
Make sure you are executing `wta` from inside a Git repository.

### `Warning: Project detected as using '<pm>', but '<pm>' is not in PATH`
Ensure your project's package manager (`pnpm`, `yarn`, `npm`, or `bun`) is installed and available in your shell's `PATH`. If you prefer to install dependencies manually or use a different tool, you can safely run your install command inside the worktree directory.
