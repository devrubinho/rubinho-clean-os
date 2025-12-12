#!/bin/bash

# clean_space.sh
# Safely removes temporary files, caches, and old logs on macOS
# Usage:
#   ./clean_space.sh          - Cleans only current user
#   sudo ./clean_space.sh     - Cleans all users
#   ./clean_space.sh --dry-run - Preview what will be cleaned without deleting
#   ./clean_space.sh --log    - Save cleanup log to file

# ────────────────────────────────
# System Check
# ────────────────────────────────

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script only works on macOS"
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
        echo -e "$items_list"
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
                        items_list=$(sudo ls -1 "$dir" 2>/dev/null | head -10 | sed 's/^/  • /')
                    else
                        items_list=$(ls -1 "$dir" 2>/dev/null | head -10 | sed 's/^/  • /')
                    fi
                else
                    # Show first 5 items if more than 10
                    if [ "$use_sudo" = "true" ]; then
                        items_list=$(sudo ls -1 "$dir" 2>/dev/null | head -5 | sed 's/^/  • /')
                        items_list="${items_list}\n  • ... and $((item_count - 5)) more items"
                    else
                        items_list=$(ls -1 "$dir" 2>/dev/null | head -5 | sed 's/^/  • /')
                        items_list="${items_list}\n  • ... and $((item_count - 5)) more items"
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
echo -e "${BOLD}${CYAN}║            🧹  DISK SPACE CLEANUP - macOS  🧹                 ║${NC}"
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
                        if [ "$DRY_RUN" = "true" ]; then
                            log_message "[DRY-RUN] Would remove: $path"
                        else
                            log_message "Removing: $path"
                            sudo rm -rf "$path" 2>/dev/null || echo -e "${RED}     Failed to remove: $path${NC}"
                        fi
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
                        if [ "$DRY_RUN" = "true" ]; then
                            log_message "[DRY-RUN] Would remove: $path"
                        else
                            log_message "Removing: $path"
                            rm -rf "$path" 2>/dev/null || echo -e "${RED}     Failed to remove: $path${NC}"
                        fi
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
    )

    for pattern in "${file_patterns[@]}"; do
        local file_count=0
        if [ "$use_sudo" = "true" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                file_count=$(sudo find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" 2>/dev/null | wc -l | tr -d ' ')
                log_message "[DRY-RUN] Would remove $file_count '$pattern' file(s)"
            else
                file_count=$(sudo find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" -delete -print 2>/dev/null | wc -l | tr -d ' ')
                if [ "$file_count" -gt 0 ]; then
                    log_message "Removed $file_count '$pattern' file(s)"
                fi
            fi
        else
            if [ "$DRY_RUN" = "true" ]; then
                file_count=$(find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" 2>/dev/null | wc -l | tr -d ' ')
                log_message "[DRY-RUN] Would remove $file_count '$pattern' file(s)"
            else
                file_count=$(find "$user_home" -type f -name "$pattern" ! -name ".env" ! -name ".env.*" -delete -print 2>/dev/null | wc -l | tr -d ' ')
                if [ "$file_count" -gt 0 ]; then
                    log_message "Removed $file_count '$pattern' file(s)"
                fi
            fi
        fi

        if [ "$file_count" -gt 0 ] && [ "$DRY_RUN" = "false" ]; then
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
            log_message "TOTAL: $total_items items removed - ${freed_gb}.${freed_gb_decimal} GB freed"
        else
            local freed_kb=$(((total_freed % 1024) * 100 / 1024))
            echo -e "${GREEN}${BOLD}     ✅ TOTAL: $total_items items removed - ${freed_mb}.${freed_kb} MB freed${NC}"
            log_message "TOTAL: $total_items items removed - ${freed_mb}.${freed_kb} MB freed"
        fi
    else
        echo -e "${YELLOW}     • No development artifacts found${NC}"
        log_message "No development artifacts found"
    fi
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ────────────────────────────────
# Scan Cleanable Items Function
# ────────────────────────────────

scan_cleanable_items() {
    local user_home=$1
    local use_sudo=$2
    # Output goes to stdout, caller will redirect to temp file

    # Define all patterns to scan (folders)
    local folder_patterns=(
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
        "__pycache__"
        ".pytest_cache"
        ".tox"
        ".venv"
        "venv"
        ".eggs"
        ".mypy_cache"
        ".ruff_cache"
        ".hypothesis"
        ".pytype"
        "htmlcov"
        ".coverage"
        "vendor"
        "coverage"
        "playwright-report"
        ".vitest"
        ".idea"
    )

    # Scan folders
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
    done

    # Scan files
    local file_patterns=(
        ".eslintcache"
        ".prettier-cache"
        ".tsbuildinfo"
        "*.pyc"
        "*.pyo"
        "*.pyd"
        ".coverage"
        "coverage.xml"
        "nosetests.xml"
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
    done
}

# ────────────────────────────────
# Main Cleanup Process
# ────────────────────────────────

# Scan for development artifacts first
echo -e "${CYAN}🔍 Scanning for development artifacts...${NC}"
CLEANABLE_TEMP=$(mktemp)
(
    scan_cleanable_items "$ORIGINAL_HOME" "false" > "$CLEANABLE_TEMP"
) &
SCAN_PID=$!
show_progress "$SCAN_PID" "  Scanning for cleanable items"
wait "$SCAN_PID" 2>/dev/null

if [ -s "$CLEANABLE_TEMP" ]; then
    # Group by item name and sum sizes
    GROUPED_TEMP=$(mktemp)
    awk '{
        path = $3
        # Extract item name (last component of path)
        n = split(path, parts, "/")
        item_name = parts[n]

        # Special handling for known patterns
        if (path ~ /\/vendor\/bundle$/) {
            item_name = "vendor/bundle"
        }

        size_kb = $1
        size_human = $2

        # Sum sizes and count
        sizes[item_name] += size_kb
        counts[item_name]++
    }
    END {
        # Sort by total size (descending)
        for (item in sizes) {
            printf "%d %s %d %s\n", sizes[item], item, counts[item], (counts[item] == 1 ? "item" : "items")
        }
    }' "$CLEANABLE_TEMP" | sort -rn > "$GROUPED_TEMP"

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
    done < "$GROUPED_TEMP"

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

    if ask_category_confirmation "Development Artifacts" "Remove all development build artifacts and dependencies for user $ORIGINAL_USER" "$dev_details"; then
        clean_dev_artifacts "$ORIGINAL_HOME" "$ORIGINAL_USER" false
    fi

    # Cleanup temp files
    rm -f "$CLEANABLE_TEMP" "$GROUPED_TEMP" 2>/dev/null
else
    echo ""
    echo -e "${BOLD}${YELLOW}💻 Development Artifacts${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}  ✓ No development artifacts found to clean${NC}"
    rm -f "$CLEANABLE_TEMP" 2>/dev/null
fi

# ────────────────────────────────
# Completion Summary
# ────────────────────────────────

echo ""
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${BOLD}${CYAN}🔍 Dry-run completed. No files were deleted.${NC}"
    log_message "Dry-run completed. No files were deleted."
else
    echo -e "${BOLD}${GREEN}🎉 All clean! Your macOS system is lighter now.${NC}"
    log_message "Cleanup completed successfully."
fi

if [ "$SAVE_LOG" = "true" ] && [ -n "$LOG_FILE" ]; then
    echo ""
    echo -e "${BOLD}${CYAN}📝 Cleanup log saved to: ${LOG_FILE}${NC}"
    log_message "Log file location: $LOG_FILE"
fi

echo ""
