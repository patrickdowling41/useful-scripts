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
DEFAULT_FISH_DEST_DIR="${FISH_FUNCTIONS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions}"
FISH_DEST_DIR="$DEFAULT_FISH_DEST_DIR"
ZSHRC_PATH="${ZDOTDIR:-$HOME}/.zshrc"
SHELL_TARGET=""
CLEAN_ZSHRC=false
DRY_RUN=false

print_usage() {
    cat << EOF
${BOLD}Usage:${NC} ./uninstall.sh [options]

${BOLD}Options:${NC}
  --shell <zsh|fish|both>  Which shell(s) to uninstall from.
                           Default: autodetect - act on each of zsh and fish
                           that is found on PATH. 'both' acts on both
                           unconditionally.
  -d, --dest <dir>         Zsh functions directory (default: ~/.config/zsh/functions)
  --fish-dest <dir>        Fish functions directory (default: ~/.config/fish/functions)
  --zshrc <path>           Path to .zshrc (default: ~/.zshrc)
  --clean-zshrc            Also remove autoload line from .zshrc
  -n, --dry-run            Show what would be done without making changes
  -h, --help               Display this help message

${BOLD}Notes:${NC}
  Fish needs no config cleanup: the installer only ever dropped wta.fish into
  the fish functions directory, so removing that file is the whole uninstall.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --shell)
            SHELL_TARGET="$2"
            shift 2
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
        if command -v zsh >/dev/null 2>&1; then
            DO_ZSH=true
        fi
        if command -v fish >/dev/null 2>&1; then
            DO_FISH=true
        fi
        if [ "$DO_ZSH" = false ] && [ "$DO_FISH" = false ]; then
            echo -e "${RED}Error:${NC} Neither zsh nor fish was found on PATH." >&2
            echo "       Force a target with --shell <zsh|fish|both>." >&2
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Error:${NC} Invalid --shell value: $SHELL_TARGET (expected zsh, fish or both)" >&2
        print_usage
        exit 1
        ;;
esac

echo -e "${BOLD}Uninstalling wta...${NC}\n"

SHELLS_LABEL=""
[ "$DO_ZSH" = true ] && SHELLS_LABEL="zsh"
[ "$DO_FISH" = true ] && SHELLS_LABEL="${SHELLS_LABEL:+$SHELLS_LABEL, }fish"
if [ -z "$SHELL_TARGET" ]; then
    echo -e "${BLUE}Target shells:${NC} $SHELLS_LABEL (autodetected)"
else
    echo -e "${BLUE}Target shells:${NC} $SHELLS_LABEL (--shell $SHELL_TARGET)"
fi
echo ""

# remove_function_file <target-file>
remove_function_file() {
    local target_file="$1"
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "   ${YELLOW}[dry-run]${NC} Would remove $target_file"
        else
            rm -f "$target_file"
            echo -e "   ${GREEN}✓${NC} Removed $target_file"
        fi
    else
        echo -e "   ${YELLOW}!${NC} File not found: $target_file (nothing to remove)"
    fi
}

# 1. Remove function files
if [ "$DO_ZSH" = true ]; then
    echo -e "${BLUE}Zsh${NC}"
    remove_function_file "$DEST_DIR/wta"

    # Optionally clean .zshrc
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
fi

if [ "$DO_FISH" = true ]; then
    echo -e "${BLUE}Fish${NC}"
    remove_function_file "$FISH_DEST_DIR/wta.fish"
    echo -e "   ${BLUE}i${NC} Note: fish needs no config cleanup; nothing was added to config.fish."
    echo ""
fi

echo -e "${BOLD}${GREEN}Uninstall completed.${NC}"
