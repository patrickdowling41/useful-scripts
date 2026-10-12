#!/usr/bin/env bash

# install.sh - Installer for wta (Git Worktree Add helper)
# Configures the wta function in your Zsh configuration and functions directory.

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

# Defaults
DEFAULT_DEST_DIR="${ZSH_FUNCTIONS_DIR:-$HOME/.config/zsh/functions}"
DEST_DIR="$DEFAULT_DEST_DIR"
ZSHRC_PATH="${ZDOTDIR:-$HOME}/.zshrc"
USE_SYMLINK=false
DRY_RUN=false
FORCE=false

print_usage() {
    cat << EOF
${BOLD}Usage:${NC} ./install.sh [options]

${BOLD}Options:${NC}
  -s, --symlink            Symlink wta instead of copying (useful for developers)
  -d, --dest <dir>         Functions directory (default: ~/.config/zsh/functions)
  --zshrc <path>           Path to .zshrc (default: ~/.zshrc)
  -n, --dry-run            Show what would be done without making changes
  -f, --force              Overwrite target file without confirmation
  -h, --help               Display this help message
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--symlink)
            USE_SYMLINK=true
            shift
            ;;
        -d|--dest)
            DEST_DIR="$2"
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

echo -e "${BOLD}Installing wta (Git Worktree Add helper)...${NC}\n"

# Verify source wta file exists
if [ ! -f "$SOURCE_WTA" ]; then
    echo -e "${RED}Error:${NC} Source file not found: $SOURCE_WTA" >&2
    exit 1
fi

# 1. Target functions directory
TARGET_FILE="$DEST_DIR/wta"
echo -e "${BLUE}1. Functions Directory${NC}"
echo "   Target directory: $DEST_DIR"
echo "   Target file:      $TARGET_FILE"

if [ "$DRY_RUN" = true ]; then
    echo -e "   ${YELLOW}[dry-run]${NC} Would create directory: $DEST_DIR"
    if [ "$USE_SYMLINK" = true ]; then
        echo -e "   ${YELLOW}[dry-run]${NC} Would create symlink: $TARGET_FILE -> $SOURCE_WTA"
    else
        echo -e "   ${YELLOW}[dry-run]${NC} Would copy: $SOURCE_WTA -> $TARGET_FILE"
    fi
else
    mkdir -p "$DEST_DIR"

    if [ -e "$TARGET_FILE" ] || [ -L "$TARGET_FILE" ]; then
        if [ "$FORCE" = false ] && [ -f "$TARGET_FILE" ]; then
            if cmp -s "$SOURCE_WTA" "$TARGET_FILE"; then
                echo -e "   ${GREEN}✓${NC} $TARGET_FILE is already up to date"
            else
                echo -e "   ${YELLOW}!${NC} Overwriting existing $TARGET_FILE"
            fi
        fi
        rm -f "$TARGET_FILE"
    fi

    if [ "$USE_SYMLINK" = true ]; then
        ln -sf "$SOURCE_WTA" "$TARGET_FILE"
        echo -e "   ${GREEN}✓${NC} Created symlink: $TARGET_FILE -> $SOURCE_WTA"
    else
        cp "$SOURCE_WTA" "$TARGET_FILE"
        chmod +x "$TARGET_FILE"
        echo -e "   ${GREEN}✓${NC} Installed wta to $TARGET_FILE"
    fi
fi

echo ""

# 2. Zsh configuration (~/.zshrc)
echo -e "${BLUE}2. Zsh Configuration${NC}"
echo "   Target zshrc:     $ZSHRC_PATH"

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

# 3. Verification
echo -e "${BLUE}3. Verification${NC}"
if command -v zsh >/dev/null 2>&1; then
    if [ "$DRY_RUN" = false ]; then
        TEST_OUTPUT=$(zsh -c "fpath=('$DEST_DIR' \$fpath); autoload -Uz wta; whence -w wta" 2>&1) || true
        if [[ "$TEST_OUTPUT" == *"function"* ]]; then
            echo -e "   ${GREEN}✓${NC} Verification successful: 'wta' successfully loaded by zsh."
        else
            echo -e "   ${YELLOW}!${NC} Notice: zsh could not verify autoload immediately. Output: $TEST_OUTPUT"
        fi
    else
        echo -e "   ${YELLOW}[dry-run]${NC} Skipped verification check"
    fi
else
    echo -e "   ${YELLOW}!${NC} zsh command not found in PATH; skipping verification."
fi

echo ""
echo -e "${BOLD}${GREEN}Installation Complete!${NC}"
echo ""
echo -e "To activate wta in your current terminal session, run:"
echo -e "  ${BOLD}source $ZSHRC_PATH${NC}"
echo ""
echo -e "Or simply open a new terminal window."
echo ""
echo -e "Usage:"
echo -e "  ${BOLD}wta <branch-name>${NC}    # Create and setup worktree"
echo -e "  ${BOLD}wta --help${NC}           # Show usage information"
