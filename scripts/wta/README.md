# `wta` (Git Worktree Add Helper)

A shell function that streamlines creating and preparing Git worktrees for feature development and bug fixes. Ships in two native implementations — Zsh and Fish — with identical behaviour.

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
├── wta.sh          # Zsh function source
├── wta.fish        # Fish function source (same behaviour as wta.sh)
├── install.sh      # Automated installer for Zsh and/or Fish
└── uninstall.sh    # Uninstaller script
```

---

## Prerequisites

- **Git** (`git --version`)
- **Zsh** (`zsh --version`) - standard default shell on macOS - *or* **Fish** (`fish --version`). You only need the shell you actually use; the installer detects which are present.
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

By default the installer **autodetects** which of Zsh and Fish are on your `PATH` and installs for each one it finds, skipping any that is missing. Use `--shell` to override that.

#### What `install.sh` does for Zsh:
1. Copies `wta` into your custom Zsh functions directory (`~/.config/zsh/functions/wta`).
2. Configures your `~/.zshrc` (if not already configured):
   - Adds `fpath=(~/.config/zsh/functions $fpath)`
   - Adds `autoload -Uz wta`
3. Backs up your `~/.zshrc` before making any modifications.
4. Verifies that `wta` loads properly in Zsh.

#### What `install.sh` does for Fish:
1. Copies `wta.fish` into your Fish functions directory (`~/.config/fish/functions/wta.fish`).
2. Verifies that `wta` loads properly in Fish.

That is the whole Fish install. Fish autoloads any `<name>.fish` on its
function path, so **no `config.fish` changes are made or needed** — and
consequently there is nothing to clean up on uninstall either. Note the
filename differs per shell: Zsh wants `wta`, Fish requires `wta.fish`.

#### Installing for one shell only:

```bash
./scripts/wta/install.sh --shell fish    # Fish only
./scripts/wta/install.sh --shell zsh     # Zsh only
./scripts/wta/install.sh --shell both    # both, even if one is not installed yet
```

`--shell both` and the autodetect default are not quite the same: autodetect
skips a shell that is missing, whereas `both` installs for both regardless,
which is useful when provisioning a machine before the shell itself is there.

#### Developer / Symlink Mode:
If you want edits in this repository to immediately reflect in your shell without re-running the installer, use `--symlink` (or `-s`):

```bash
./scripts/wta/install.sh --symlink
```

#### Installer Options:

| Option | Description |
| :--- | :--- |
| `--shell <zsh\|fish\|both>` | Which shell(s) to install for (default: autodetect) |
| `-s, --symlink` | Symlink `wta` instead of copying |
| `-d, --dest <dir>` | Zsh functions destination directory (default: `~/.config/zsh/functions`) |
| `--fish-dest <dir>` | Fish functions destination directory (default: `~/.config/fish/functions`) |
| `--zshrc <path>` | Custom path to `.zshrc` (default: `~/.zshrc`) |
| `-n, --dry-run` | Preview changes without modifying files |
| `-f, --force` | Overwrite existing files without prompt |
| `-h, --help` | Display help message |

---

### Method 2: Manual Installation

If you prefer to configure your shell manually:

#### Zsh

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

#### Fish

1. **Create the functions directory:**
   ```bash
   mkdir -p ~/.config/fish/functions
   ```

2. **Copy (or symlink) `wta.fish` into it, keeping the `.fish` name:**
   ```bash
   cp scripts/wta/wta.fish ~/.config/fish/functions/wta.fish
   ```

3. **That's it.** Fish autoloads the function by filename, so there is nothing
   to add to `config.fish`. Open a new shell, or load it into the current one:
   ```fish
   source ~/.config/fish/functions/wta.fish
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

Like the installer, this autodetects your shells by default and accepts
`--shell zsh|fish|both`.

To also clean up the autoload line in `~/.zshrc`:

```bash
./scripts/wta/uninstall.sh --clean-zshrc
```

Fish needs no equivalent flag — removing `~/.config/fish/functions/wta.fish`
is the entire uninstall, because nothing was ever added to `config.fish`.

#### Uninstaller Options:

| Option | Description |
| :--- | :--- |
| `--shell <zsh\|fish\|both>` | Which shell(s) to uninstall from (default: autodetect) |
| `-d, --dest <dir>` | Zsh functions directory (default: `~/.config/zsh/functions`) |
| `--fish-dest <dir>` | Fish functions directory (default: `~/.config/fish/functions`) |
| `--zshrc <path>` | Custom path to `.zshrc` (default: `~/.zshrc`) |
| `--clean-zshrc` | Also remove the autoload line from `.zshrc` |
| `-n, --dry-run` | Preview changes without modifying files |
| `-h, --help` | Display help message |

---

## Troubleshooting

### `command not found: wta`

**Zsh:**
1. Make sure `~/.config/zsh/functions` is in your `fpath` before `autoload -Uz wta`:
   ```bash
   echo $fpath
   ```
2. Reload your `.zshrc`:
   ```bash
   source ~/.zshrc
   ```

**Fish:**
1. Check the file is there and named exactly `wta.fish` — Fish matches the
   function name to the filename, so `wta` without the extension will not load:
   ```fish
   ls ~/.config/fish/functions/wta.fish
   ```
2. Confirm that directory is on the function path:
   ```fish
   echo $fish_function_path | tr ' ' '\n'
   ```
3. Ask Fish directly whether it can see the function:
   ```fish
   functions -q wta; echo $status   # 0 means found
   ```

### `Error: Not a git repository`
Make sure you are executing `wta` from inside a Git repository.

### `Warning: Project detected as using '<pm>', but '<pm>' is not in PATH`
Ensure your project's package manager (`pnpm`, `yarn`, `npm`, or `bun`) is installed and available in your shell's `PATH`. If you prefer to install dependencies manually or use a different tool, you can safely run your install command inside the worktree directory.
