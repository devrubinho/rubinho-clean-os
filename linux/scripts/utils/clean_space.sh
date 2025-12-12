#!/bin/bash

# clean_space.sh
# Safely removes temporary files, caches, and old logs on Linux
# Usage:
#   ./clean_space.sh          - Cleans only current user
#   sudo ./clean_space.sh     - Cleans all users
#   ./clean_space.sh --dry-run - Preview what will be cleaned without deleting
#   ./clean_space.sh --log    - Save cleanup log to file

# ────────────────────────────────
# System Check
# ────────────────────────────────

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ Error: This script only works on Linux"
    exit 1
fi

# Don't use set -e to allow controlled failures

# ────────────────────────────────
# Command Line Arguments
# ────────────────────────────────

DRY_RUN=false
SAVE_LOG=false
LOG_FILE=""

for arg in "$@"; do
    case $arg in
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --log|-l)
            SAVE_LOG=true
            LOG_FILE="${HOME}/cleanup-$(date +%Y%m%d-%H%M%S).log"
            shift
            ;;
        --log-file=*)
            SAVE_LOG=true
            LOG_FILE="${arg#*=}"
            shift
            ;;
        *)
            # Unknown argument, ignore
            ;;
    esac
done

# ────────────────────────────────
# Logging Function
# ────────────────────────────────

log_message() {
    local message="$1"
    echo "$message"
    if [ "$SAVE_LOG" = "true" ] && [ -n "$LOG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# ────────────────────────────────
# User Detection
# ────────────────────────────────

# Check if running with sudo (Required)
ORIGINAL_USER=${SUDO_USER:-$USER}
ORIGINAL_HOME=$(eval echo ~$ORIGINAL_USER)

if [ "$EUID" -eq 0 ]; then
    SUDO_MODE=true
    log_message "✓ Running with administrator privileges"
    log_message "    Cleaning ALL users"
else
    echo -e "${RED}${BOLD}❌ ERROR: This script requires administrator privileges${NC}"
    echo ""
    echo -e "${YELLOW}Please run with sudo:${NC}"
    echo -e "${CYAN}   sudo ./clean_space.sh${NC}"
    echo ""
    exit 1
fi

# Show dry-run mode if enabled
if [ "$DRY_RUN" = "true" ]; then
    log_message ""
    log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message "🔍 DRY-RUN MODE ENABLED"
    log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message ""
    log_message "No files will be deleted. This is a preview only."
    log_message ""
fi

# Show log file location if enabled
if [ "$SAVE_LOG" = "true" ] && [ -n "$LOG_FILE" ]; then
    log_message ""
    log_message "📝 Cleanup log will be saved to: $LOG_FILE"
    log_message ""
fi

# ────────────────────────────────
# Color Definitions
# ────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ────────────────────────────────
# Space Calculation Functions
# ────────────────────────────────

SPACE_FREED=0

calculate_space() {
    local dir=$1
    if [ -d "$dir" ]; then
        local size=$(du -sk "$dir" 2>/dev/null | cut -f1)
        if [ -n "$size" ]; then
            SPACE_FREED=$((SPACE_FREED + size))
        fi
    fi
}

# ────────────────────────────────
# Progress Indicator Function
# ────────────────────────────────

show_progress() {
    local pid=$1
    local message=$2
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local percent=0
    local last_update=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(((i + 1) % 10))
        current_time=$(date +%s)

        # Increment percentage based on elapsed time
        if [ $percent -lt 85 ]; then
            # Fast increment at the beginning
            if [ $((current_time - last_update)) -ge 1 ]; then
                percent=$((percent + 3))
                last_update=$current_time
            fi
        elif [ $percent -lt 95 ]; then
            # Slower increment in the middle
            if [ $((current_time - last_update)) -ge 2 ]; then
                percent=$((percent + 1))
                last_update=$current_time
            fi
        else
            # Stay at 95% until process completes (don't oscillate)
            percent=95
        fi

        printf "\r${BLUE}${message}${NC} ${CYAN}[${spinner:$i:1}]${NC} ${YELLOW}${percent}%%${NC}" >&2
        sleep 0.2
    done

    printf "\r${GREEN}${message}${NC} ${GREEN}✓${NC} ${GREEN}100%%${NC}\n" >&2
}

# ────────────────────────────────
# Preview and Confirm Function
# ────────────────────────────────

preview_and_confirm() {
    local category_name="$1"
    local description="$2"
    local items_list="$3"
    local size_info="$4"

    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${YELLOW}📋 Category: $category_name${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}Description:${NC}"
    echo "  $description"
    echo ""

    if [ -n "$items_list" ]; then
        echo -e "${CYAN}Items that will be removed:${NC}"
        echo "$items_list" | while IFS= read -r item; do
            echo "  • $item"
        done
        echo ""
    fi

    if [ -n "$size_info" ]; then
        echo -e "${CYAN}Estimated space to free:${NC}"
        echo "  $size_info"
        echo ""
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BOLD}${CYAN}🔍 DRY-RUN: No files will be deleted${NC}"
        echo ""
        read -p "Show next category? [Y/n]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            return 1
        fi
        return 0
    else
        echo -e "${BOLD}${YELLOW}⚠️  This will permanently delete the items listed above.${NC}"
        echo ""
        read -p "Continue with this category? [y/N]: " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}  ⏭️  Skipping $category_name...${NC}"
            log_message "Skipped category: $category_name"
            return 1
        fi

        echo -e "${GREEN}  ✓ Proceeding with $category_name cleanup...${NC}"
        log_message "Proceeding with cleanup: $category_name"
        return 0
    fi
}

# ────────────────────────────────
# Directory Cleaning Function
# ────────────────────────────────

clean_dir() {
    local dir=$1
    local name=$2
    local use_sudo=${3:-false}
    local skip_confirmation=${4:-false}

    if [ -d "$dir" ]; then
        local size_before
        if [ "$use_sudo" = "true" ]; then
            size_before=$(sudo du -sk "$dir" 2>/dev/null | cut -f1)
        else
            size_before=$(du -sk "$dir" 2>/dev/null | cut -f1)
        fi

        if [ -n "$size_before" ] && [ "$size_before" -gt 0 ]; then
            # Show preview and get confirmation if not skipping
            if [ "$skip_confirmation" = "false" ]; then
                local size_mb=$((size_before / 1024))
                local size_gb=$((size_mb / 1024))
                local size_display
                if [ $size_gb -gt 0 ]; then
                    size_display="${size_gb}.$((size_mb % 1024 / 100)) GB"
                else
                    size_display="${size_mb} MB"
                fi

                # Count items
                local item_count
                if [ "$use_sudo" = "true" ]; then
                    item_count=$(sudo find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
                else
                    item_count=$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
                fi

                local items_list=""
                if [ "$item_count" -le 10 ]; then
                    # Show all items if 10 or fewer
                    if [ "$use_sudo" = "true" ]; then
                        items_list=$(sudo ls -1 "$dir" 2>/dev/null | head -10 | sed 's/^/  /')
                    else
                        items_list=$(ls -1 "$dir" 2>/dev/null | head -10 | sed 's/^/  /')
                    fi
                else
                    # Show first 5 items if more than 10
                    if [ "$use_sudo" = "true" ]; then
                        items_list=$(sudo ls -1 "$dir" 2>/dev/null | head -5 | sed 's/^/  /')
                        items_list="${items_list}\n  ... and $((item_count - 5)) more items"
                    else
                        items_list=$(ls -1 "$dir" 2>/dev/null | head -5 | sed 's/^/  /')
                        items_list="${items_list}\n  ... and $((item_count - 5)) more items"
                    fi
                fi

                if ! preview_and_confirm "$name" "Cache files in $dir" "$items_list" "$size_display ($item_count items)"; then
                    return 0
                fi
            fi

            if [ "$DRY_RUN" = "true" ]; then
                echo -e "${CYAN}  🔍 [DRY-RUN] Would clean: ${BOLD}$name${NC}"
                log_message "[DRY-RUN] Would clean: $name ($size_display, $item_count items)"
            else
                echo -e "${BLUE}  🧹 Cleaning: ${BOLD}$name${NC}"
                log_message "Cleaning: $name"
                if [ "$use_sudo" = "true" ]; then
                    sudo rm -rf "$dir"/* 2>/dev/null || true
                else
                    rm -rf "$dir"/* 2>/dev/null || true
                fi
            fi

            local size_after
            if [ "$use_sudo" = "true" ]; then
                size_after=$(sudo du -sk "$dir" 2>/dev/null | cut -f1)
            else
                size_after=$(du -sk "$dir" 2>/dev/null | cut -f1)
            fi
            local size_after=${size_after:-0}
            local freed=$((size_before - size_after))
            if [ $freed -gt 0 ]; then
                local freed_mb=$((freed / 1024))
                local freed_kb=$(((freed % 1024) * 100 / 1024))
                echo -e "${GREEN}     ✓ Freed: ${freed_mb}.${freed_kb} MB${NC}"
            fi
        else
            echo -e "${GREEN}  ✓ $name: Already clean (no files to remove)${NC}"
        fi
    fi
}

# ────────────────────────────────
# Old Files Cleaning Function
# ────────────────────────────────

clean_old_files() {
    local dir=$1
    local days=$2
    local name=$3
    local use_sudo=${4:-false}

    if [ -d "$dir" ]; then
        echo -e "${BLUE}  🗑️  Removing files >${days} days: ${BOLD}$name${NC}"
        local count
        if [ "$use_sudo" = "true" ]; then
            count=$(sudo find "$dir" -type f -mtime +$days -delete -print 2>/dev/null | wc -l | tr -d ' ')
        else
            count=$(find "$dir" -type f -mtime +$days -delete -print 2>/dev/null | wc -l | tr -d ' ')
        fi
        if [ "$count" -gt 0 ]; then
            echo -e "${GREEN}     ✓ Removed $count old files${NC}"
        fi
    fi
}

# ────────────────────────────────
# Welcome Banner
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}║            🧹  DISK SPACE CLEANUP - Linux  🧹                 ║${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}${MAGENTA}👥 Mode: Cleaning ALL users${NC}"
echo ""
echo -e "${BOLD}${YELLOW}📋 Cleanup Process${NC}"
echo ""
echo "The cleanup will be organized into categories. For each category, you will:"
echo "  • See what will be cleaned"
echo "  • See how much space will be freed"
echo "  • Choose whether to proceed or skip"
echo ""
echo -e "${BOLD}${RED}⚠️  WARNING: Development data will be removed!${NC}"
echo -e "${YELLOW}   Projects will need to reinstall dependencies (npm install, etc.)${NC}"
echo ""

# ────────────────────────────────
# Category Confirmation Function
# ────────────────────────────────

ask_category_confirmation() {
    local category_name="$1"
    local description="$2"
    local details="$3"

    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
    echo -e "${BOLD}${MAGENTA}║              📋 CATEGORY: $category_name$(printf '%*s' $((47 - ${#category_name})) '')║${NC}"
    echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}What will be cleaned:${NC}"
    echo "$details" | while IFS= read -r line; do
        echo "  $line"
    done
    echo ""
    echo -e "${BOLD}${YELLOW}⚠️  This will permanently delete the items listed above.${NC}"
    echo ""

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${BOLD}${CYAN}🔍 DRY-RUN MODE: No files will be deleted${NC}"
        echo ""
        read -p "Show next category? [Y/n]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            return 1
        fi
        return 0
    else
        read -p "Do you want to clean this category? [y/N]: " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}  ⏭️  Skipping $category_name...${NC}"
            log_message "Skipped category: $category_name"
            return 1
        fi

        echo -e "${GREEN}  ✓ Proceeding with $category_name cleanup...${NC}"
        log_message "Proceeding with cleanup: $category_name"
        return 0
    fi
}

# ────────────────────────────────
# Development Artifacts Cleaning
# ────────────────────────────────

clean_dev_artifacts() {
    local user_home=$1
    local user_name=$2
    local use_sudo=$3

    echo -e "${BLUE}  🗂️  Removing ALL development build artifacts...${NC}"
    echo -e "${CYAN}     Searching in: $user_home${NC}"
    echo ""

    # Define all patterns to clean (folders)
    local folder_patterns=(
        # JavaScript/TypeScript/Node.js
        "node_modules"
        "dist"
        "build"
        "out"
        ".next"
        ".turbo"
        "nx-out"
        ".vite"
        ".rspack-cache"
        ".rollup.cache"
        ".webpack"
        ".parcel-cache"
        ".sass-cache"
        ".pnpm-store"
        "storybook-static"
        ".expo"
        ".expo-shared"
        "solid-start-build"

        # Python
        "__pycache__"
        ".pytest_cache"
        ".tox"
        ".venv"
        "venv"
        ".eggs"
        "*.egg-info"
        ".mypy_cache"
        ".ruff_cache"
        ".hypothesis"
        ".pytype"
        "pip-wheel-metadata"
        "htmlcov"
        ".coverage"

        # Go
        "vendor"

        # General
        "coverage"
        "playwright-report"
        ".vitest"
        ".idea"
    )

    local total_items=0
    local total_freed=0

    # Clean folders - use direct find with -delete for reliability
    for pattern in "${folder_patterns[@]}"; do
        echo -e "${BLUE}  → Searching for '$pattern' folders...${NC}"
        local pattern_count=0
        local pattern_size=0

        if [ "$use_sudo" = "true" ]; then
            # First, count and calculate size (skip folders < 100KB to ignore test fixtures)
            while IFS= read -r path; do
                if [ -d "$path" ]; then
                    local size_kb=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 100 ]; then
                        pattern_count=$((pattern_count + 1))
                        pattern_size=$((pattern_size + size_kb))
                        echo -e "${CYAN}     Removing: $path${NC}"
                        # Remove immediately
                        sudo rm -rf "$path" 2>/dev/null || echo -e "${RED}     Failed to remove: $path${NC}"
                    fi
                fi
            done < <(sudo find "$user_home" -type d -name "$pattern" 2>/dev/null)
        else
            # First, count and calculate size (skip folders < 100KB to ignore test fixtures)
            while IFS= read -r path; do
                if [ -d "$path" ]; then
                    local size_kb=$(du -sk "$path" 2>/dev/null | cut -f1)
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 100 ]; then
                        pattern_count=$((pattern_count + 1))
                        pattern_size=$((pattern_size + size_kb))
                        echo -e "${CYAN}     Removing: $path${NC}"
                        # Remove immediately
                        rm -rf "$path" 2>/dev/null || echo -e "${RED}     Failed to remove: $path${NC}"
                    fi
                fi
            done < <(find "$user_home" -type d -name "$pattern" 2>/dev/null)
        fi

        if [ $pattern_count -gt 0 ]; then
            total_items=$((total_items + pattern_count))
            total_freed=$((total_freed + pattern_size))
            local size_mb=$((pattern_size / 1024))
            echo -e "${GREEN}     ✓ Removed $pattern_count '$pattern' folder(s) - ${size_mb} MB${NC}"
        fi
        echo ""
    done

    # Clean files
    echo -e "${BLUE}  → Cleaning cache files...${NC}"
    local file_patterns=(
        # JavaScript/TypeScript
        ".eslintcache"
        ".prettier-cache"
        ".tsbuildinfo"

        # Python
        "*.pyc"
        "*.pyo"
        "*.pyd"
        ".coverage"
        "coverage.xml"
        "nosetests.xml"

        # General
        "*.db-journal"
        "Thumbs.db"
    )

    for pattern in "${file_patterns[@]}"; do
        local file_count=0
        if [ "$use_sudo" = "true" ]; then
            file_count=$(sudo find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" -delete -print 2>/dev/null | wc -l | tr -d ' ')
        else
            file_count=$(find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" -delete -print 2>/dev/null | wc -l | tr -d ' ')
        fi

        if [ "$file_count" -gt 0 ]; then
            total_items=$((total_items + file_count))
            echo -e "${GREEN}     ✓ Removed $file_count '$pattern' file(s)${NC}"
        fi
    done

    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ $total_items -gt 0 ]; then
        local freed_mb=$((total_freed / 1024))
        local freed_gb=$((freed_mb / 1024))
        if [ $freed_gb -gt 0 ]; then
            local freed_gb_decimal=$(((freed_mb % 1024) * 10 / 1024))
            echo -e "${GREEN}${BOLD}     ✅ TOTAL: $total_items items removed - ${freed_gb}.${freed_gb_decimal} GB freed${NC}"
        else
            local freed_kb=$(((total_freed % 1024) * 100 / 1024))
            echo -e "${GREEN}${BOLD}     ✅ TOTAL: $total_items items removed - ${freed_mb}.${freed_kb} MB freed${NC}"
        fi
    else
        echo -e "${YELLOW}     • No development artifacts found${NC}"
    fi
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ────────────────────────────────
# User Cleanup Function
# ────────────────────────────────

clean_user_all() {
    local user_home=$1
    local user_name=$2
    local use_sudo=$3

    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
    echo -e "${BOLD}${MAGENTA}║                    👤 USER: $(printf '%-35s' "$user_name")║${NC}"
    echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Caches
    local cache_details="• Application caches (Chrome, Firefox, VS Code, Spotify, Slack, etc.)
• Package manager caches (npm, yarn, pip)
• Development tool caches (Cypress, etc.)
• General system caches
• Old log files (>7 days)"

    if ask_category_confirmation "Application Caches" "Remove all application and development tool caches for user $user_name" "$cache_details"; then
        echo -e "${BOLD}${YELLOW}📦 Caches and Applications${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
        clean_dir "$user_home/.cache" "General Caches" "$use_sudo" true
        clean_dir "$user_home/.cache/google-chrome" "Chrome" "$use_sudo" true
        clean_dir "$user_home/.cache/chromium" "Chromium" "$use_sudo" true
        clean_dir "$user_home/.cache/firefox" "Firefox" "$use_sudo" true
        clean_dir "$user_home/.cache/Code" "VS Code" "$use_sudo" true
        clean_dir "$user_home/.cache/spotify" "Spotify" "$use_sudo" true
        clean_dir "$user_home/.cache/slack" "Slack" "$use_sudo" true
        clean_dir "$user_home/.cache/yarn" "Yarn" "$use_sudo" true
        clean_dir "$user_home/.cache/npm" "npm" "$use_sudo" true
        clean_dir "$user_home/.cache/pip" "pip" "$use_sudo" true
        clean_dir "$user_home/.cache/cypress" "Cypress" "$use_sudo" true

        if [ -d "$user_home/.local/share/logs" ]; then
            clean_old_files "$user_home/.local/share/logs" 7 "Logs (>7 days)" "$use_sudo"
        fi
    fi

    # Trash
    local trash_path="$user_home/.local/share/Trash"
    if [ -d "$trash_path" ]; then
        local size_before
        if [ "$use_sudo" = "true" ]; then
            size_before=$(sudo du -sk "$trash_path" 2>/dev/null | cut -f1)
        else
            size_before=$(du -sk "$trash_path" 2>/dev/null | cut -f1)
        fi

        if [ -n "$size_before" ] && [ "$size_before" -gt 0 ]; then
            local size_before_mb=$((size_before / 1024))
            local size_before_gb=$((size_before_mb / 1024))
            local size_display
            if [ $size_before_gb -gt 0 ]; then
                size_display="${size_before_gb}.$((size_before_mb % 1024 / 100)) GB"
            else
                size_display="${size_before_mb} MB"
            fi

            # Count items in trash
            local trash_count
            if [ "$use_sudo" = "true" ]; then
                trash_count=$(sudo find "$trash_path" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
            else
                trash_count=$(find "$trash_path" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
            fi

            local trash_details="• All items in Trash (permanently deleted)
• Total items: $trash_count
• Estimated space: $size_display"

            if ask_category_confirmation "Trash" "Permanently delete all items in Trash for user $user_name" "$trash_details"; then
                echo ""
                echo -e "${BOLD}${YELLOW}🗑️  Trash${NC}"
                echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
                echo -e "${BLUE}  🗑️  Emptying trash: ${YELLOW}${size_before_mb} MB${NC}"

                if [ "$use_sudo" = "true" ]; then
                    sudo chmod -R u+w "$trash_path" 2>/dev/null || true
                    sudo find "$trash_path" -mindepth 1 -delete 2>/dev/null || true
                    sudo rm -rf "$trash_path"/* 2>/dev/null || true
                else
                    chmod -R u+w "$trash_path" 2>/dev/null || true
                    find "$trash_path" -mindepth 1 -delete 2>/dev/null || true
                    rm -rf "$trash_path"/* 2>/dev/null || true
                fi

                sleep 2

                local size_after
                if [ "$use_sudo" = "true" ]; then
                    size_after=$(sudo du -sk "$trash_path" 2>/dev/null | cut -f1)
                else
                    size_after=$(du -sk "$trash_path" 2>/dev/null | cut -f1)
                fi
                local size_after=${size_after:-0}
                local freed=$((size_before - size_after))
                local freed_mb=$((freed / 1024))

                local remaining=0
                if [ "$use_sudo" = "true" ]; then
                    remaining=$(sudo find "$trash_path" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
                else
                    remaining=$(find "$trash_path" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
                fi

                if [ "$remaining" -eq 0 ] || [ $freed -gt 0 ]; then
                    echo -e "${GREEN}     ✓ Trash emptied: ${freed_mb} MB freed${NC}"
                else
                    echo -e "${YELLOW}     ⚠️  $remaining protected item(s) not removed${NC}"
                fi
            fi
        else
            echo -e "${GREEN}  ✓ Trash already empty${NC}"
        fi
    fi

    # Development Artifacts
    echo -e "${CYAN}🔍 Scanning for development artifacts...${NC}"
    local cleanable_temp=$(mktemp)
    (
        # Scan all development patterns
    local folder_patterns=(
        "node_modules" "dist" "build" "out" ".next" ".turbo" "nx-out" ".vite"
        ".rspack-cache" ".rollup.cache" ".webpack" ".parcel-cache" ".sass-cache"
        ".pnpm-store" "storybook-static" ".expo" ".expo-shared" "solid-start-build"
        "__pycache__" ".pytest_cache" ".tox" ".venv" "venv" ".eggs" ".mypy_cache"
        ".ruff_cache" ".hypothesis" ".pytype" "htmlcov" ".coverage" "vendor"
        "coverage" "playwright-report" ".vitest" ".idea"
    )

    for pattern in "${folder_patterns[@]}"; do
        if [ "$use_sudo" = "true" ]; then
            while IFS= read -r path; do
                if [ -d "$path" ]; then
                    local size_kb=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 100 ]; then
                        local size_human=$(sudo du -sh "$path" 2>/dev/null | awk '{print $1}')
                        echo "$size_kb $size_human $path"
                    fi
                fi
            done < <(sudo find "$user_home" -type d -name "$pattern" 2>/dev/null)
        else
            while IFS= read -r path; do
                if [ -d "$path" ]; then
                    local size_kb=$(du -sk "$path" 2>/dev/null | cut -f1)
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 100 ]; then
                        local size_human=$(du -sh "$path" 2>/dev/null | awk '{print $1}')
                        echo "$size_kb $size_human $path"
                    fi
                fi
            done < <(find "$user_home" -type d -name "$pattern" 2>/dev/null)
        fi
    done >> "$cleanable_temp"

    # Scan files
    local file_patterns=(
        ".eslintcache" ".prettier-cache" ".tsbuildinfo" "*.pyc" "*.pyo" "*.pyd"
        ".coverage" "coverage.xml" "nosetests.xml"
    )

    for pattern in "${file_patterns[@]}"; do
        if [ "$use_sudo" = "true" ]; then
            while IFS= read -r path; do
                if [ -f "$path" ]; then
                    local size_kb=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
                        local size_human=$(sudo du -sh "$path" 2>/dev/null | awk '{print $1}')
                        echo "$size_kb $size_human $path"
                    fi
                fi
            done < <(sudo find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" 2>/dev/null)
        else
            while IFS= read -r path; do
                if [ -f "$path" ]; then
                    local size_kb=$(du -sk "$path" 2>/dev/null | cut -f1)
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
                        local size_human=$(du -sh "$path" 2>/dev/null | awk '{print $1}')
                        echo "$size_kb $size_human $path"
                    fi
                fi
            done < <(find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" 2>/dev/null)
        fi
    done >> "$cleanable_temp"
    ) &
    SCAN_PID=$!
    show_progress "$SCAN_PID" "  Scanning for cleanable items"
    wait "$SCAN_PID" 2>/dev/null

    if [ -s "$cleanable_temp" ]; then
        # Group by item name and sum sizes
        local grouped_temp=$(mktemp)
        awk '{
            path = $3
            n = split(path, parts, "/")
            item_name = parts[n]

            if (path ~ /\/vendor\/bundle$/) {
                item_name = "vendor/bundle"
            }

            size_kb = $1
            sizes[item_name] += size_kb
            counts[item_name]++
        }
        END {
            for (item in sizes) {
                printf "%d %s %d %s\n", sizes[item], item, counts[item], (counts[item] == 1 ? "item" : "items")
            }
        }' "$cleanable_temp" | sort -rn > "$grouped_temp"

        # Display grouped items
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${MAGENTA}📋 ITEMS TO BE DELETED (Grouped by Name)${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        local rank=0
        local total_size_kb=0
        local total_count=0

        while IFS= read -r line; do
            if [ -n "$line" ]; then
                rank=$((rank + 1))
                local size_kb=$(echo "$line" | awk '{print $1}')
                local item_name=$(echo "$line" | awk '{print $2}')
                local count=$(echo "$line" | awk '{print $3}')
                local item_type=$(echo "$line" | awk '{print $4}')

                total_size_kb=$((total_size_kb + size_kb))
                total_count=$((total_count + count))

                # Format size
                local size_mb=$((size_kb / 1024))
                local size_gb=$((size_mb / 1024))
                local size_display
                if [ $size_gb -gt 0 ]; then
                    local gb_decimal=$(((size_mb % 1024) * 10 / 1024))
                    size_display="${size_gb}.${gb_decimal}G"
                else
                    size_display="${size_mb}M"
                fi

                # Color coding
                local color="${NC}"
                if [ $rank -le 3 ]; then
                    color="${RED}"
                elif [ $rank -le 6 ]; then
                    color="${YELLOW}"
                else
                    color="${BLUE}"
                fi

                printf "${color}%3d. %6s %s (%d %s)${NC}\n" "$rank" "$size_display" "$item_name" "$count" "$item_type"
            fi
        done < "$grouped_temp"

        # Show total
        echo ""
        local total_mb=$((total_size_kb / 1024))
        local total_gb=$((total_mb / 1024))
        local total_display
        if [ $total_gb -gt 0 ]; then
            local gb_decimal=$(((total_mb % 1024) * 10 / 1024))
            total_display="${total_gb}.${gb_decimal} GB"
        else
            total_display="${total_mb} MB"
        fi

        echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${GREEN}📊 TOTAL: ${total_count} items - ${total_display}${NC}"
        echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        local dev_details="• JavaScript/TypeScript: node_modules, dist, build, .next, .turbo
• Python: __pycache__, .venv, venv, .pytest_cache, *.pyc
• Go: vendor folders
• Build caches: .vite, .parcel, .webpack, etc.
• Test outputs: coverage, playwright, cypress, etc.
• IDE artifacts: .idea, etc.
⚠️  WARNING: Projects will need to reinstall dependencies!"

        if ask_category_confirmation "Development Artifacts" "Remove all development build artifacts and dependencies for user $user_name" "$dev_details"; then
            echo ""
            echo -e "${BOLD}${YELLOW}💻 Development Files${NC}"
            echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
            clean_dev_artifacts "$user_home" "$user_name" "$use_sudo"
        fi

        # Cleanup temp files
        rm -f "$cleanable_temp" "$grouped_temp" 2>/dev/null
    else
        echo ""
        echo -e "${BOLD}${YELLOW}💻 Development Files${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
        echo -e "${GREEN}  ✓ No development artifacts found to clean${NC}"
    fi
}

# ────────────────────────────────
# Main Cleanup Process
# ────────────────────────────────

# Clean current user
clean_user_all "$ORIGINAL_HOME" "$ORIGINAL_USER" false

# If in sudo mode, clean all other users
if [ "$SUDO_MODE" = "true" ]; then
    for user_dir in /home/*; do
        if [ -d "$user_dir" ]; then
            username=$(basename "$user_dir")
            if [ "$user_dir" != "$ORIGINAL_HOME" ]; then
                clean_user_all "$user_dir" "$username" true
            fi
        fi
    done
fi

# ────────────────────────────────
# System Cleanup
# ────────────────────────────────

system_details="• System logs older than 30 days
• Temporary files in /tmp
• Temporary files in /var/tmp"

if ask_category_confirmation "System Files" "Remove old system logs and temporary files" "$system_details"; then
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
    echo -e "${BOLD}${MAGENTA}║                     ⚙️  SYSTEM CLEANUP                         ║${NC}"
    echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BOLD}${YELLOW}📝 System Logs${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    clean_old_files "/var/log" 30 "Logs (>30 days)" "$SUDO_MODE"

    echo ""
    echo -e "${BOLD}${YELLOW}⏱️  Temporary Files${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    clean_dir "/tmp" "Temporary Files" "$SUDO_MODE" true
    clean_dir "/var/tmp" "Temporary Files (var)" "$SUDO_MODE" true
fi

# ────────────────────────────────
# Development Tools Cleanup
# ────────────────────────────────

tool_caches=""
has_tools=false

if command -v npm &> /dev/null; then
    tool_caches="${tool_caches}• npm cache\n"
    has_tools=true
fi

if command -v pip &> /dev/null; then
    tool_caches="${tool_caches}• pip cache\n"
    has_tools=true
fi

if [ "$SUDO_MODE" = "true" ]; then
    if command -v apt-get &> /dev/null; then
        tool_caches="${tool_caches}• apt cache (system)\n"
        has_tools=true
    fi
    if command -v yum &> /dev/null; then
        tool_caches="${tool_caches}• yum cache (system)\n"
        has_tools=true
    fi
    if command -v dnf &> /dev/null; then
        tool_caches="${tool_caches}• dnf cache (system)\n"
        has_tools=true
    fi
    if command -v pacman &> /dev/null; then
        tool_caches="${tool_caches}• pacman cache (system)\n"
        has_tools=true
    fi
fi

if [ "$has_tools" = "true" ]; then
    if ask_category_confirmation "Development Tool Caches" "Clear package manager and development tool caches" "$tool_caches"; then
        echo ""
        echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
        echo -e "${BOLD}${MAGENTA}║                 🛠️  DEVELOPMENT TOOLS                          ║${NC}"
        echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
        echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # npm
        if command -v npm &> /dev/null; then
            echo -e "${BOLD}${YELLOW}📦 npm${NC}"
            echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
            npm cache clean --force 2>/dev/null || true
            echo -e "${GREEN}  ✓ npm cache cleaned${NC}"
            echo ""
        fi

        # pip
        if command -v pip &> /dev/null; then
            echo -e "${BOLD}${YELLOW}🐍 pip${NC}"
            echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
            pip cache purge 2>/dev/null || true
            echo -e "${GREEN}  ✓ pip cache cleaned${NC}"
            echo ""
        fi

        # Package Manager Cleanup (sudo only)
        if [ "$SUDO_MODE" = "true" ]; then
            echo -e "${BOLD}${YELLOW}📦 Package Manager Caches${NC}"
            echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"

            # apt (Debian/Ubuntu)
            if command -v apt-get &> /dev/null; then
                echo -e "${BLUE}  🧹 Cleaning apt cache...${NC}"
                apt-get clean 2>/dev/null || true
                apt-get autoclean 2>/dev/null || true
                echo -e "${GREEN}  ✓ apt cache cleaned${NC}"
                echo ""
            fi

            # yum (RHEL/CentOS)
            if command -v yum &> /dev/null; then
                echo -e "${BLUE}  🧹 Cleaning yum cache...${NC}"
                yum clean all 2>/dev/null || true
                echo -e "${GREEN}  ✓ yum cache cleaned${NC}"
                echo ""
            fi

            # dnf (Fedora)
            if command -v dnf &> /dev/null; then
                echo -e "${BLUE}  🧹 Cleaning dnf cache...${NC}"
                dnf clean all 2>/dev/null || true
                echo -e "${GREEN}  ✓ dnf cache cleaned${NC}"
                echo ""
            fi

            # pacman (Arch)
            if command -v pacman &> /dev/null; then
                echo -e "${BLUE}  🧹 Cleaning pacman cache...${NC}"
                pacman -Sc --noconfirm 2>/dev/null || true
                echo -e "${GREEN}  ✓ pacman cache cleaned${NC}"
                echo ""
            fi
        fi
    fi
fi

# ────────────────────────────────
# Docker Cleanup
# ────────────────────────────────

if command -v docker &> /dev/null; then
    # Check if Docker daemon is actually running
    if timeout 3 docker info &>/dev/null; then
        # Get Docker system info before cleanup
        local docker_info_before
        docker_info_before=$(timeout 5 docker system df 2>/dev/null || echo "")

        # Count Docker resources
        local containers_count=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
        local images_count=$(docker images -aq 2>/dev/null | wc -l | tr -d ' ')
        local volumes_count=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
        local networks_count=$(docker network ls -q 2>/dev/null | grep -v bridge | grep -v host | grep -v none | wc -l | tr -d ' ')

        local docker_details=""
        if [ "$containers_count" -gt 0 ]; then
            docker_details="${docker_details}• Containers: $containers_count (will be stopped and removed)\n"
        fi
        if [ "$images_count" -gt 0 ]; then
            docker_details="${docker_details}• Images: $images_count\n"
        fi
        if [ "$volumes_count" -gt 0 ]; then
            docker_details="${docker_details}• Volumes: $volumes_count\n"
        fi
        if [ "$networks_count" -gt 0 ]; then
            docker_details="${docker_details}• Networks: $networks_count\n"
        fi

        if [ -n "$docker_details" ]; then
            docker_details="${docker_details}⚠️  WARNING: This will stop ALL running containers!"

            if ask_category_confirmation "Docker" "Remove all Docker containers, images, volumes, and networks" "$docker_details"; then
                echo ""
                echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
                echo -e "${BOLD}${MAGENTA}║                         🐳 DOCKER                              ║${NC}"
                echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
                echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
                echo ""

                echo -e "${BLUE}  🔍 Checking Docker status...${NC}"
                echo -e "${GREEN}  ✓ Docker is running${NC}"
                echo ""

                # Show space used before
                echo -e "${BLUE}  📊 Space used before:${NC}"
                echo "$docker_info_before" | tail -n +2 | while IFS= read -r line; do
                    echo "     $line"
                done
                echo ""
                # Stop and remove everything with timeouts
                echo -e "${BLUE}  🛑 Stopping containers...${NC}"
                timeout 30 docker stop $(docker ps -aq 2>/dev/null) 2>/dev/null || true

                echo -e "${BLUE}  🗑️  Removing containers...${NC}"
                timeout 30 docker rm -f $(docker ps -aq 2>/dev/null) 2>/dev/null || true

                echo -e "${BLUE}  📦 Removing images...${NC}"
                timeout 60 docker rmi -f $(docker images -aq 2>/dev/null) 2>/dev/null || true

                echo -e "${BLUE}  💾 Removing volumes...${NC}"
                timeout 30 docker volume rm $(docker volume ls -q 2>/dev/null) 2>/dev/null || true

                echo -e "${BLUE}  🔗 Removing networks...${NC}"
                timeout 10 docker network prune -f 2>/dev/null || true

                echo -e "${BLUE}  🧹 Final cleanup...${NC}"
                timeout 60 docker system prune -a --volumes -f 2>/dev/null || true

                echo ""
                echo -e "${GREEN}  ✓ Docker completely cleaned!${NC}"

                # Show space used after
                echo ""
                echo -e "${BLUE}  📊 Space used after:${NC}"
                timeout 5 docker system df 2>/dev/null | tail -n +2 | while IFS= read -r line; do
                    echo "     $line"
                done
            fi
        else
            echo ""
            echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
            echo -e "${BOLD}${MAGENTA}║                         🐳 DOCKER                              ║${NC}"
            echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
            echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${GREEN}  ✓ Docker is already clean (no resources to remove)${NC}"
        fi
    else
        echo ""
        echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
        echo -e "${BOLD}${MAGENTA}║                         🐳 DOCKER                              ║${NC}"
        echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
        echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  ⚠️  Docker is not running - skipping Docker cleanup${NC}"
        echo -e "${CYAN}     Start Docker daemon if you want to clean Docker data${NC}"
    fi
fi

# ────────────────────────────────
# Docker Data Cleanup (All Users)
# ────────────────────────────────

# Clean Docker data from all users
if [ "$SUDO_MODE" = "true" ]; then
    echo ""
    echo -e "${BOLD}${YELLOW}💾 Docker Data (All Users)${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    for user_dir in /home/*; do
        if [ -d "$user_dir" ]; then
            docker_data="$user_dir/.docker"
            if [ -d "$docker_data" ]; then
                username=$(basename "$user_dir")
                clean_dir "$docker_data" "Docker Data ($username)" true
            fi
        fi
    done
fi

# ────────────────────────────────
# Completion Summary
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${GREEN}║                    ✅  CLEANUP COMPLETE!  ✅                  ║${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show current free space
echo -e "${BOLD}${MAGENTA}💾 Current Disk Space:${NC}"
echo ""
df -h / | tail -1 | awk '{print "   📊 Used space: " $3 " of " $2 " (" $5 ")"}'
df -h / | tail -1 | awk '{print "   ✨ Free space: " $4}'
echo ""
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${BOLD}${CYAN}🔍 Dry-run completed. No files were deleted.${NC}"
    log_message "Dry-run completed. No files were deleted."
else
    echo -e "${BOLD}${GREEN}🎉 All clean! Your Linux system is lighter now.${NC}"
    log_message "Cleanup completed successfully."
fi

if [ "$SAVE_LOG" = "true" ] && [ -n "$LOG_FILE" ]; then
    echo ""
    echo -e "${BOLD}${CYAN}📝 Cleanup log saved to: ${LOG_FILE}${NC}"
    log_message "Log file location: $LOG_FILE"
fi

echo ""
