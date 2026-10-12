#!/usr/bin/env bash

# uninstall.sh - Uninstaller for wta (Git Worktree Add helper)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

DEFAULT_DEST_DIR="${ZSH_FUNCTIONS_DIR:-$HOME/.config/zsh/functions}"
DEST_DIR="$DEFAULT_DEST_DIR"
ZSHRC_PATH="${ZDOTDIR:-$HOME}/.zshrc"
CLEAN_ZSHRC=false
DRY_RUN=false

print_usage() {
    cat << EOF
${BOLD}Usage:${NC} ./uninstall.sh [options]

${BOLD}Options:${NC}
  -d, --dest <dir>         Functions directory (default: ~/.config/zsh/functions)
  --zshrc <path>           Path to .zshrc (default: ~/.zshrc)
  --clean-zshrc            Also remove autoload line from .zshrc
  -n, --dry-run            Show what would be done without making changes
  -h, --help               Display this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dest)
            DEST_DIR="$2"
            shift 2
            ;;
        --zshrc)
            ZSHRC_PATH="$2"
            shift 2
            ;;
        --clean-zshrc)
            CLEAN_ZSHRC=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
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

TARGET_FILE="$DEST_DIR/wta"

echo -e "${BOLD}Uninstalling wta...${NC}\n"

# 1. Remove function file
if [ -e "$TARGET_FILE" ] || [ -L "$TARGET_FILE" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo -e "   ${YELLOW}[dry-run]${NC} Would remove $TARGET_FILE"
    else
        rm -f "$TARGET_FILE"
        echo -e "   ${GREEN}✓${NC} Removed $TARGET_FILE"
    fi
else
    echo -e "   ${YELLOW}!${NC} File not found: $TARGET_FILE (nothing to remove)"
fi

# 2. Optionally clean .zshrc
if [ "$CLEAN_ZSHRC" = true ] && [ -f "$ZSHRC_PATH" ]; then
    if grep -q "autoload.*\<wta\>" "$ZSHRC_PATH"; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "   ${YELLOW}[dry-run]${NC} Would remove wta autoload line from $ZSHRC_PATH"
        else
            BACKUP_FILE="${ZSHRC_PATH}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$ZSHRC_PATH" "$BACKUP_FILE"
            # Remove autoload -Uz wta and preceding comment if any
            sed -i.tmp '/# Lazy-load the wta function/d' "$ZSHRC_PATH" && rm -f "$ZSHRC_PATH.tmp"
            sed -i.tmp '/autoload.*wta/d' "$ZSHRC_PATH" && rm -f "$ZSHRC_PATH.tmp"
            echo -e "   ${GREEN}✓${NC} Removed wta autoload from $ZSHRC_PATH (backup: $(basename "$BACKUP_FILE"))"
        fi
    fi
else
    echo -e "   ${BLUE}i${NC} Note: .zshrc was not modified. To clean it up manually or run with --clean-zshrc"
fi

echo ""
echo -e "${BOLD}${GREEN}Uninstall completed.${NC}"
