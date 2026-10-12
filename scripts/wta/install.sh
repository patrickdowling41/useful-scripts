#!/usr/bin/env bash

# install.sh - Installer for wta (Git Worktree Add helper)
# Configures the wta function for Zsh and/or Fish.

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/wta.sh" ]; then
    SOURCE_WTA="$SCRIPT_DIR/wta.sh"
elif [ -f "$SCRIPT_DIR/wta" ]; then
    SOURCE_WTA="$SCRIPT_DIR/wta"
else
    SOURCE_WTA="$SCRIPT_DIR/wta.sh"
fi
SOURCE_WTA_FISH="$SCRIPT_DIR/wta.fish"

# Defaults
DEFAULT_DEST_DIR="${ZSH_FUNCTIONS_DIR:-$HOME/.config/zsh/functions}"
DEST_DIR="$DEFAULT_DEST_DIR"
DEFAULT_FISH_DEST_DIR="${FISH_FUNCTIONS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions}"
FISH_DEST_DIR="$DEFAULT_FISH_DEST_DIR"
ZSHRC_PATH="${ZDOTDIR:-$HOME}/.zshrc"
SHELL_TARGET=""
USE_SYMLINK=false
DRY_RUN=false
FORCE=false

print_usage() {
    cat << EOF
${BOLD}Usage:${NC} ./install.sh [options]

${BOLD}Options:${NC}
  --shell <zsh|fish|both>  Which shell(s) to install for.
                           Default: autodetect - install for each of zsh and
                           fish that is found on PATH, skipping any that is
                           missing. 'both' installs for both unconditionally,
                           even if a shell is not installed yet.
  -s, --symlink            Symlink wta instead of copying (useful for developers)
  -d, --dest <dir>         Zsh functions directory (default: ~/.config/zsh/functions)
  --fish-dest <dir>        Fish functions directory (default: ~/.config/fish/functions)
  --zshrc <path>           Path to .zshrc (default: ~/.zshrc)
  -n, --dry-run            Show what would be done without making changes
  -f, --force              Overwrite target file without confirmation
  -h, --help               Display this help message

${BOLD}Notes:${NC}
  Zsh needs two lines in .zshrc (fpath + autoload), which this script adds.
  Fish autoloads wta.fish from its functions directory, so no config.fish
  changes are made or needed.
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --shell)
            SHELL_TARGET="$2"
            shift 2
            ;;
        -s|--symlink)
            USE_SYMLINK=true
            shift
            ;;
        -d|--dest)
            DEST_DIR="$2"
            shift 2
            ;;
        --fish-dest)
            FISH_DEST_DIR="$2"
            shift 2
            ;;
        --zshrc)
            ZSHRC_PATH="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Resolve which shells to act on
DO_ZSH=false
DO_FISH=false
case "$SHELL_TARGET" in
    zsh)
        DO_ZSH=true
        ;;
    fish)
        DO_FISH=true
        ;;
    both)
        DO_ZSH=true
        DO_FISH=true
        ;;
    "")
        # Autodetect: act on whichever shells are actually installed.
        if command -v zsh >/dev/null 2>&1; then
            DO_ZSH=true
        fi
        if command -v fish >/dev/null 2>&1; then
            DO_FISH=true
        fi
        if [ "$DO_ZSH" = false ] && [ "$DO_FISH" = false ]; then
            echo -e "${RED}Error:${NC} Neither zsh nor fish was found on PATH." >&2
            echo "       Install one, or force a target with --shell <zsh|fish|both>." >&2
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Error:${NC} Invalid --shell value: $SHELL_TARGET (expected zsh, fish or both)" >&2
        print_usage
        exit 1
        ;;
esac

echo -e "${BOLD}Installing wta (Git Worktree Add helper)...${NC}\n"

SHELLS_LABEL=""
[ "$DO_ZSH" = true ] && SHELLS_LABEL="zsh"
[ "$DO_FISH" = true ] && SHELLS_LABEL="${SHELLS_LABEL:+$SHELLS_LABEL, }fish"
if [ -z "$SHELL_TARGET" ]; then
    echo -e "${BLUE}Target shells:${NC} $SHELLS_LABEL (autodetected)"
else
    echo -e "${BLUE}Target shells:${NC} $SHELLS_LABEL (--shell $SHELL_TARGET)"
fi
echo ""

# install_function_file <source> <target-file> <label>
# Copies or symlinks the function file, honouring --dry-run/--symlink/--force.
install_function_file() {
    local src="$1"
    local target_file="$2"
    local target_dir
    target_dir="$(dirname "$target_file")"

    echo "   Target directory: $target_dir"
    echo "   Target file:      $target_file"

    if [ "$DRY_RUN" = true ]; then
        echo -e "   ${YELLOW}[dry-run]${NC} Would create directory: $target_dir"
        if [ "$USE_SYMLINK" = true ]; then
            echo -e "   ${YELLOW}[dry-run]${NC} Would create symlink: $target_file -> $src"
        else
            echo -e "   ${YELLOW}[dry-run]${NC} Would copy: $src -> $target_file"
        fi
        return 0
    fi

    mkdir -p "$target_dir"

    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        if [ "$FORCE" = false ] && [ -f "$target_file" ]; then
            if cmp -s "$src" "$target_file"; then
                echo -e "   ${GREEN}✓${NC} $target_file is already up to date"
            else
                echo -e "   ${YELLOW}!${NC} Overwriting existing $target_file"
            fi
        fi
        rm -f "$target_file"
    fi

    if [ "$USE_SYMLINK" = true ]; then
        ln -sf "$src" "$target_file"
        echo -e "   ${GREEN}✓${NC} Created symlink: $target_file -> $src"
    else
        cp "$src" "$target_file"
        chmod +x "$target_file"
        echo -e "   ${GREEN}✓${NC} Installed wta to $target_file"
    fi
}

STEP=1

# ---------------------------------------------------------------- zsh ---------
if [ "$DO_ZSH" = true ]; then
    # Verify source wta file exists
    if [ ! -f "$SOURCE_WTA" ]; then
        echo -e "${RED}Error:${NC} Source file not found: $SOURCE_WTA" >&2
        exit 1
    fi

    echo -e "${BLUE}${STEP}. Zsh Functions Directory${NC}"
    install_function_file "$SOURCE_WTA" "$DEST_DIR/wta"
    STEP=$((STEP + 1))
    echo ""

    # Zsh configuration (~/.zshrc)
    echo -e "${BLUE}${STEP}. Zsh Configuration${NC}"
    echo "   Target zshrc:     $ZSHRC_PATH"
    STEP=$((STEP + 1))

    if [ ! -f "$ZSHRC_PATH" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "   ${YELLOW}[dry-run]${NC} Would create $ZSHRC_PATH"
        else
            touch "$ZSHRC_PATH"
            echo -e "   ${GREEN}✓${NC} Created empty $ZSHRC_PATH"
        fi
    fi

    # Determine what needs to be added
    # Formatted fpath string depending on whether dest_dir is inside $HOME
    if [[ "$DEST_DIR" == "$HOME"* ]]; then
        REL_DEST_DIR="~${DEST_DIR#"$HOME"}"
    else
        REL_DEST_DIR="$DEST_DIR"
    fi

    FPATH_LINE="fpath=($REL_DEST_DIR \$fpath)"
    AUTOLOAD_LINE="autoload -Uz wta"

    NEED_FPATH=true
    NEED_AUTOLOAD=true

    if [ -f "$ZSHRC_PATH" ]; then
        # Check if this destination or relative path is already in an fpath assignment
        if grep -q "fpath=" "$ZSHRC_PATH" 2>/dev/null && {
            grep -E "fpath=.*(\.config/zsh/functions|\$HOME/\.config/zsh/functions|~/\.config/zsh/functions)" "$ZSHRC_PATH" >/dev/null 2>&1 || \
            grep -F "$DEST_DIR" "$ZSHRC_PATH" >/dev/null 2>&1 || \
            grep -F "$REL_DEST_DIR" "$ZSHRC_PATH" >/dev/null 2>&1
        }; then
            NEED_FPATH=false
        fi

        # Check if autoload -Uz wta (or autoload wta) is already present
        if grep -qE 'autoload.*\<wta\>' "$ZSHRC_PATH" 2>/dev/null; then
            NEED_AUTOLOAD=false
        fi
    fi

    if [ "$NEED_FPATH" = false ] && [ "$NEED_AUTOLOAD" = false ]; then
        echo -e "   ${GREEN}✓${NC} fpath is already configured in $ZSHRC_PATH"
        echo -e "   ${GREEN}✓${NC} 'autoload -Uz wta' is already present in $ZSHRC_PATH"
        echo -e "   ${GREEN}✓${NC} No changes needed in $ZSHRC_PATH"
    else
        if [ "$NEED_FPATH" = false ]; then
            echo -e "   ${GREEN}✓${NC} fpath is already configured in $ZSHRC_PATH"
        fi
        if [ "$NEED_AUTOLOAD" = false ]; then
            echo -e "   ${GREEN}✓${NC} 'autoload -Uz wta' is already present in $ZSHRC_PATH"
        fi

        LINES_TO_ADD=""
        if [ "$NEED_FPATH" = true ]; then
            LINES_TO_ADD="${LINES_TO_ADD}# Add custom functions directory to Zsh path"$'\n'"$FPATH_LINE"$'\n'
        fi
        if [ "$NEED_AUTOLOAD" = true ]; then
            LINES_TO_ADD="${LINES_TO_ADD}# Lazy-load the wta function"$'\n'"$AUTOLOAD_LINE"$'\n'
        fi

        if [ "$DRY_RUN" = true ]; then
            echo -e "   ${YELLOW}[dry-run]${NC} Would append the following to $ZSHRC_PATH:"
            echo "$LINES_TO_ADD" | sed 's/^/     /'
        else
            # Backup ~/.zshrc
            BACKUP_FILE="${ZSHRC_PATH}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$ZSHRC_PATH" "$BACKUP_FILE"
            echo -e "   ${GREEN}✓${NC} Backed up $ZSHRC_PATH to $(basename "$BACKUP_FILE")"

            # Ensure newline at end of file before appending
            if [ -s "$ZSHRC_PATH" ] && [ "$(tail -c 1 "$ZSHRC_PATH")" != "" ]; then
                echo "" >> "$ZSHRC_PATH"
            fi

            echo "" >> "$ZSHRC_PATH"
            printf "%s" "$LINES_TO_ADD" >> "$ZSHRC_PATH"
            echo -e "   ${GREEN}✓${NC} Added wta configuration to $ZSHRC_PATH"
        fi
    fi

    echo ""
fi

# --------------------------------------------------------------- fish ---------
if [ "$DO_FISH" = true ]; then
    if [ ! -f "$SOURCE_WTA_FISH" ]; then
        echo -e "${RED}Error:${NC} Source file not found: $SOURCE_WTA_FISH" >&2
        exit 1
    fi

    echo -e "${BLUE}${STEP}. Fish Functions Directory${NC}"
    # Fish autoloads a function from <name>.fish on $fish_function_path, so the
    # installed basename must be wta.fish - unlike zsh, which wants plain 'wta'.
    install_function_file "$SOURCE_WTA_FISH" "$FISH_DEST_DIR/wta.fish"
    STEP=$((STEP + 1))
    echo -e "   ${BLUE}i${NC} Fish autoloads this file; no config.fish changes needed."
    echo ""
fi

# -------------------------------------------------------- verification --------
echo -e "${BLUE}${STEP}. Verification${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "   ${YELLOW}[dry-run]${NC} Skipped verification check"
else
    if [ "$DO_ZSH" = true ]; then
        if command -v zsh >/dev/null 2>&1; then
            TEST_OUTPUT=$(zsh -c "fpath=('$DEST_DIR' \$fpath); autoload -Uz wta; whence -w wta" 2>&1) || true
            if [[ "$TEST_OUTPUT" == *"function"* ]]; then
                echo -e "   ${GREEN}✓${NC} Verification successful: 'wta' successfully loaded by zsh."
            else
                echo -e "   ${YELLOW}!${NC} Notice: zsh could not verify autoload immediately. Output: $TEST_OUTPUT"
            fi
        else
            echo -e "   ${YELLOW}!${NC} zsh command not found in PATH; skipping zsh verification."
        fi
    fi

    if [ "$DO_FISH" = true ]; then
        if command -v fish >/dev/null 2>&1; then
            # Point fish at the parent of the functions dir so autoload applies.
            FISH_CONFIG_PARENT="$(dirname "$FISH_DEST_DIR")"
            if fish -c "set -p fish_function_path '$FISH_DEST_DIR'; functions -q wta" >/dev/null 2>&1; then
                echo -e "   ${GREEN}✓${NC} Verification successful: 'wta' successfully loaded by fish."
            else
                echo -e "   ${YELLOW}!${NC} Notice: fish could not verify autoload immediately."
                echo -e "       Checked function path: $FISH_DEST_DIR (config dir: $FISH_CONFIG_PARENT)"
            fi
        else
            echo -e "   ${YELLOW}!${NC} fish command not found in PATH; skipping fish verification."
        fi
    fi
fi

echo ""
echo -e "${BOLD}${GREEN}Installation Complete!${NC}"
echo ""
if [ "$DO_ZSH" = true ]; then
    echo -e "To activate wta in your current zsh session, run:"
    echo -e "  ${BOLD}source $ZSHRC_PATH${NC}"
fi
if [ "$DO_FISH" = true ]; then
    echo -e "Fish picks wta up automatically in any new shell - nothing to source."
fi
echo ""
echo -e "Or simply open a new terminal window."
echo ""
echo -e "Usage:"
echo -e "  ${BOLD}wta <branch-name>${NC}    # Create and setup worktree"
echo -e "  ${BOLD}wta --help${NC}           # Show usage information"
