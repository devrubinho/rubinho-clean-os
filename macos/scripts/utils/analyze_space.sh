#!/bin/bash

# analyze_space.sh
# Analyzes disk space usage on macOS by finding the largest
# folders and files, with per-user breakdown and visual rankings
# Usage:
#   sudo ./analyze_space.sh   - Recommended for full system access
#   ./analyze_space.sh        - Limited to current user

# ────────────────────────────────
# System Check
# ────────────────────────────────

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script only works on macOS"
    exit 1
fi

# ────────────────────────────────
# Color Definitions (Early)
# ────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ────────────────────────────────
# Analysis Type Selection
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}    DISK SPACE ANALYSIS - Type Selection${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}What would you like to analyze?${NC}"
echo ""
echo -e "${CYAN}  1) 📁 Folders (Directories)${NC}"
echo -e "${CYAN}     Analyze disk space usage by folders${NC}"
echo ""
echo -e "${CYAN}  2) 📄 Files${NC}"
echo -e "${CYAN}     Analyze disk space usage by individual files${NC}"
echo ""
echo -n "Enter your choice [1-2]: "
read -r ANALYSIS_TYPE

# Validate analysis type
if [[ -z "$ANALYSIS_TYPE" ]]; then
    ANALYSIS_TYPE=1
    echo -e "${GREEN}✓ Using default: Folders${NC}"
elif ! [[ "$ANALYSIS_TYPE" =~ ^[12]$ ]]; then
    echo -e "${RED}⚠️  Invalid choice. Using default: Folders${NC}"
    ANALYSIS_TYPE=1
fi

if [ "$ANALYSIS_TYPE" = "1" ]; then
    ANALYSIS_MODE="folders"
    ANALYSIS_NAME="FOLDERS"
    ANALYSIS_ICON="📁"
else
    ANALYSIS_MODE="files"
    ANALYSIS_NAME="FILES"
    ANALYSIS_ICON="📄"
fi

echo ""
echo -e "${GREEN}✓ Selected: ${ANALYSIS_NAME}${NC}"
echo ""

# ────────────────────────────────
# User Configuration
# ────────────────────────────────

# Default number of items to analyze
DEFAULT_ITEMS=50

# Ask user for number of items
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}    DISK SPACE ANALYSIS - Configuration${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}How many items do you want to analyze?${NC}"
echo -e "${CYAN}  • Enter a number (10-500)${NC}"
echo -e "${CYAN}  • Press Enter for default (${DEFAULT_ITEMS})${NC}"
echo ""
echo -n "Number of items: "
read -r NUM_ITEMS

# Validate and set number of items
if [[ -z "$NUM_ITEMS" ]]; then
    NUM_ITEMS=$DEFAULT_ITEMS
    echo -e "${GREEN}✓ Using default: ${NUM_ITEMS} items${NC}"
elif ! [[ "$NUM_ITEMS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}⚠️  Invalid input. Using default: ${DEFAULT_ITEMS} items${NC}"
    NUM_ITEMS=$DEFAULT_ITEMS
elif [ "$NUM_ITEMS" -lt 10 ]; then
    echo -e "${YELLOW}⚠️  Minimum is 10 items. Using 10.${NC}"
    NUM_ITEMS=10
elif [ "$NUM_ITEMS" -gt 500 ]; then
    echo -e "${YELLOW}⚠️  Maximum is 500 items. Using 500.${NC}"
    NUM_ITEMS=500
else
    echo -e "${GREEN}✓ Analyzing top ${NUM_ITEMS} items${NC}"
fi

sleep 1

# ────────────────────────────────
# Header Display
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}║      ${ANALYSIS_ICON}  DISK SPACE ANALYSIS - TOP ${NUM_ITEMS} ${ANALYSIS_NAME}  ${ANALYSIS_ICON}$(printf '%*s' $((20 - ${#NUM_ITEMS} - ${#ANALYSIS_NAME})) '')║${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ────────────────────────────────
# Privilege Check (Required)
# ────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}❌ ERROR: This script requires administrator privileges${NC}"
    echo ""
    echo -e "${YELLOW}Please run with sudo:${NC}"
    echo -e "${CYAN}   sudo ./analyze_space.sh${NC}"
    echo ""
    exit 1
fi

    echo -e "${GREEN}✓ Running with administrator privileges${NC}"
    echo -e "${BLUE}  Full system analysis will be performed${NC}"
    echo ""

# ────────────────────────────────
# Target Directory Selection
# ────────────────────────────────

# Modern macOS uses /System/Volumes/Data for user data (APFS container)
# Fall back to / for older systems or if the path doesn't exist
TARGET="/System/Volumes/Data"
if [ ! -d "$TARGET" ]; then
    TARGET="/"
fi

echo -e "${BOLD}${MAGENTA}🔍 Analyzing: $TARGET${NC}"
echo -e "${YELLOW}⏳ This may take a few minutes... Please wait.${NC}"
echo ""

# ────────────────────────────────
# Temporary File Setup
# ────────────────────────────────

TEMP_DIRS=$(mktemp)
TEMP_FILES=$(mktemp)

cleanup() {
    rm -f "$TEMP_DIRS" "$TEMP_FILES" "$TEMP_DIRS.counts" 2>/dev/null
}
trap cleanup EXIT

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
# Data Collection (Optimized)
# ────────────────────────────────

SEARCH_LIMIT=$((NUM_ITEMS * 3))

if [ "$ANALYSIS_MODE" = "folders" ]; then
    echo -e "${BLUE}📂 Finding largest directories...${NC}"
    # Use find with maxdepth to get top-level directories first, then du on each
    (
find "$TARGET" -maxdepth 3 -type d 2>/dev/null | while read -r dir; do
    du -shx "$dir" 2>/dev/null
        done | sort -rh | head -n $SEARCH_LIMIT > "$TEMP_DIRS"
    ) &
    FIND_PID=$!
    show_progress "$FIND_PID" "  Scanning directories"
    wait "$FIND_PID" 2>/dev/null
    echo ""
else
echo -e "${BLUE}📄 Finding largest files...${NC}"
# Find large files directly (over 100MB to speed things up)
    (
        find "$TARGET" -type f -size +100M 2>/dev/null -exec du -h {} \; | sort -rh | head -n $SEARCH_LIMIT > "$TEMP_FILES"
    ) &
    FIND_PID=$!
    show_progress "$FIND_PID" "  Scanning files"
    wait "$FIND_PID" 2>/dev/null
echo ""
fi

# ────────────────────────────────
# Display Results Based on Analysis Type
# ────────────────────────────────

echo -e "${BLUE}🔄 Processing results...${NC}"
# Small delay to show processing
sleep 0.5
echo ""

if [ "$ANALYSIS_MODE" = "folders" ]; then
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${MAGENTA}📁 TOP ${NUM_ITEMS} LARGEST FOLDERS${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -s "$TEMP_DIRS" ]; then
    threshold1=$((NUM_ITEMS / 5))
    threshold2=$((NUM_ITEMS / 2))
    head -n $NUM_ITEMS "$TEMP_DIRS" | nl -w3 -s' ' | while IFS= read -r line; do
        num=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        path=$(echo "$line" | awk '{$1=""; $2=""; print substr($0,3)}')

        if [ "$num" -le "$threshold1" ]; then
            printf "${RED}${BOLD}%3s.${NC} ${YELLOW}%-10s${NC} %s\n" "$num" "$size" "$path"
        elif [ "$num" -le "$threshold2" ]; then
            printf "${YELLOW}%3s.${NC} ${GREEN}%-10s${NC} %s\n" "$num" "$size" "$path"
        else
            printf "${BLUE}%3s.${NC} %-10s %s\n" "$num" "$size" "$path"
        fi
    done
else
    echo -e "${YELLOW}  No directories found or no access permission${NC}"
fi
else
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${MAGENTA}📄 TOP ${NUM_ITEMS} LARGEST FILES${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -s "$TEMP_FILES" ]; then
    threshold1=$((NUM_ITEMS / 5))
    threshold2=$((NUM_ITEMS / 2))
    head -n $NUM_ITEMS "$TEMP_FILES" | nl -w3 -s' ' | while IFS= read -r line; do
        num=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        path=$(echo "$line" | awk '{$1=""; $2=""; print substr($0,3)}')

        if [ "$num" -le "$threshold1" ]; then
            printf "${RED}${BOLD}%3s.${NC} ${YELLOW}%-10s${NC} %s\n" "$num" "$size" "$path"
        elif [ "$num" -le "$threshold2" ]; then
            printf "${YELLOW}%3s.${NC} ${GREEN}%-10s${NC} %s\n" "$num" "$size" "$path"
        else
            printf "${BLUE}%3s.${NC} %-10s %s\n" "$num" "$size" "$path"
        fi
    done
else
    echo -e "${YELLOW}  No files found or no access permission${NC}"
    fi
fi

# ────────────────────────────────
# Cleanup Summary
# ────────────────────────────────

echo ""
echo -e "${BOLD}${YELLOW}💡 Would you like to see what could be deleted?${NC}"
echo ""
read -p "Show cleanup opportunities? [Y/n]: " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${CYAN}Returning to main menu...${NC}"
    exit 0
fi

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              🧹  CLEANUP OPPORTUNITIES SUMMARY  🧹            ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}🔍 Analyzing cleanup opportunities...${NC}"

# Function to count non-empty folders system-wide
count_folders() {
    local pattern=$1
    local min_size=${2:-100}
    local count=0

    if [ "$EUID" -eq 0 ]; then
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size" ] && [ "$size" -gt "$min_size" ]; then
                    count=$((count + 1))
                fi
            fi
        done < <(sudo find /Users -type d -name "$pattern" 2>/dev/null)
    else
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size=$(du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size" ] && [ "$size" -gt "$min_size" ]; then
                    count=$((count + 1))
                fi
            fi
        done < <(find /Users -type d -name "$pattern" 2>/dev/null)
    fi

    echo "$count"
}

# Count all artifacts with progress
(
TOTAL_NODE_MODULES=$(count_folders "node_modules")
TOTAL_NEXT=$(count_folders ".next")
TOTAL_DIST=$(count_folders "dist")
TOTAL_PYCACHE=$(count_folders "__pycache__" 10)
TOTAL_VENV=$(count_folders "venv")
TOTAL_PYTEST=$(count_folders ".pytest_cache" 10)
TOTAL_GO_VENDOR=$(count_folders "vendor")
    TOTAL_RUBY_GEMS=$(count_folders ".gems")
    TOTAL_RUBY_BUNDLE=$(count_folders ".bundle")
    # Count vendor/bundle separately (it's a path, not just a name)
    TOTAL_RUBY_VENDOR_BUNDLE=0
    for user_dir in /Users/*; do
        if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
            if [ -d "$user_dir/vendor/bundle" ]; then
                local size_kb
                if [ "$EUID" -eq 0 ]; then
                    size_kb=$(sudo du -sk "$user_dir/vendor/bundle" 2>/dev/null | cut -f1)
                else
                    size_kb=$(du -sk "$user_dir/vendor/bundle" 2>/dev/null | cut -f1)
                fi
                if [ -n "$size_kb" ] && [ "$size_kb" -gt 100 ]; then
                    TOTAL_RUBY_VENDOR_BUNDLE=$((TOTAL_RUBY_VENDOR_BUNDLE + 1))
                fi
            fi
        fi
    done

# Count cache and trash
TOTAL_CACHE_SIZE=0
for user_dir in /Users/*; do
    if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
        if [ -d "$user_dir/Library/Caches" ]; then
            cache_size=$(du -sk "$user_dir/Library/Caches" 2>/dev/null | cut -f1)
            if [ -n "$cache_size" ] && [ "$cache_size" -gt 0 ]; then
                TOTAL_CACHE_SIZE=$((TOTAL_CACHE_SIZE + cache_size))
            fi
        fi
    fi
done
TOTAL_CACHE_SIZE_MB=$((TOTAL_CACHE_SIZE / 1024))

TOTAL_TRASH_ITEMS=0
TOTAL_TRASH_SIZE=0
for user_dir in /Users/*; do
    if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
        if [ -d "$user_dir/.Trash" ]; then
            trash_count=$(find "$user_dir/.Trash" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
            trash_size=$(du -sk "$user_dir/.Trash" 2>/dev/null | cut -f1)
            if [ -n "$trash_count" ]; then
                TOTAL_TRASH_ITEMS=$((TOTAL_TRASH_ITEMS + trash_count))
            fi
            if [ -n "$trash_size" ]; then
                TOTAL_TRASH_SIZE=$((TOTAL_TRASH_SIZE + trash_size))
            fi
        fi
    fi
done
TOTAL_TRASH_SIZE_MB=$((TOTAL_TRASH_SIZE / 1024))

    # Export variables for use after subshell
    echo "TOTAL_NODE_MODULES=$TOTAL_NODE_MODULES
TOTAL_NEXT=$TOTAL_NEXT
TOTAL_DIST=$TOTAL_DIST
TOTAL_PYCACHE=$TOTAL_PYCACHE
TOTAL_VENV=$TOTAL_VENV
TOTAL_PYTEST=$TOTAL_PYTEST
TOTAL_GO_VENDOR=$TOTAL_GO_VENDOR
TOTAL_RUBY_GEMS=$TOTAL_RUBY_GEMS
TOTAL_RUBY_BUNDLE=$TOTAL_RUBY_BUNDLE
TOTAL_RUBY_VENDOR_BUNDLE=$TOTAL_RUBY_VENDOR_BUNDLE
TOTAL_CACHE_SIZE_MB=$TOTAL_CACHE_SIZE_MB
TOTAL_TRASH_ITEMS=$TOTAL_TRASH_ITEMS" > "$TEMP_DIRS.counts"
) &
COUNT_PID=$!
show_progress "$COUNT_PID" "  Counting artifacts"
wait "$COUNT_PID" 2>/dev/null

# Load counted values
if [ -f "$TEMP_DIRS.counts" ]; then
    source "$TEMP_DIRS.counts"
    rm -f "$TEMP_DIRS.counts"
fi

# Check Docker
DOCKER_STATUS="Not installed"
DOCKER_CONTAINERS=0
DOCKER_IMAGES=0
DOCKER_VOLUMES=0
if command -v docker &> /dev/null; then
    if timeout 3 docker info &>/dev/null; then
        DOCKER_STATUS="Running"
        DOCKER_CONTAINERS=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
        DOCKER_IMAGES=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')
        DOCKER_VOLUMES=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
    else
        DOCKER_STATUS="Installed but not running"
    fi
fi

# Calculate totals
TOTAL_JS=$((TOTAL_NODE_MODULES + TOTAL_NEXT + TOTAL_DIST))
TOTAL_PY=$((TOTAL_PYCACHE + TOTAL_VENV + TOTAL_PYTEST))
TOTAL_RUBY=$((TOTAL_RUBY_GEMS + TOTAL_RUBY_BUNDLE + TOTAL_RUBY_VENDOR_BUNDLE))
TOTAL_ARTIFACTS=$((TOTAL_JS + TOTAL_PY + TOTAL_GO_VENDOR + TOTAL_RUBY))

# Collect all cleanable items with sizes
CLEANABLE_TEMP=$(mktemp)
cleanup() {
    rm -f "$TEMP_DIRS" "$TEMP_FILES" "$TEMP_DIRS.counts" "$CLEANABLE_TEMP" "$GROUPED_TEMP" 2>/dev/null
}

# Function to find and size cleanable items (folders)
find_cleanable_folders() {
    local pattern=$1
    local min_size=${2:-100}

    if [ "$EUID" -eq 0 ]; then
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size_kb=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size_kb" ] && [ "$size_kb" -gt "$min_size" ]; then
                    local size_human=$(sudo du -sh "$path" 2>/dev/null | awk '{print $1}')
                    echo "$size_kb $size_human $path"
                fi
            fi
        done < <(sudo find /Users -type d -name "$pattern" 2>/dev/null)
    else
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size_kb=$(du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size_kb" ] && [ "$size_kb" -gt "$min_size" ]; then
                    local size_human=$(du -sh "$path" 2>/dev/null | awk '{print $1}')
                    echo "$size_kb $size_human $path"
                fi
            fi
        done < <(find /Users -type d -name "$pattern" 2>/dev/null)
    fi
}

# Function to find and size cleanable files
find_cleanable_files() {
    local pattern=$1
    local min_size=${2:-10485760}  # 10MB default for files

    if [ "$EUID" -eq 0 ]; then
        while IFS= read -r path; do
            if [ -f "$path" ]; then
                local size_kb=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size_kb" ] && [ "$size_kb" -gt "$min_size" ]; then
                    local size_human=$(sudo du -sh "$path" 2>/dev/null | awk '{print $1}')
                    echo "$size_kb $size_human $path"
                fi
            fi
        done < <(sudo find /Users -type f -name "$pattern" 2>/dev/null)
    else
        while IFS= read -r path; do
            if [ -f "$path" ]; then
                local size_kb=$(du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size_kb" ] && [ "$size_kb" -gt "$min_size" ]; then
                    local size_human=$(du -sh "$path" 2>/dev/null | awk '{print $1}')
                    echo "$size_kb $size_human $path"
                fi
            fi
        done < <(find /Users -type f -name "$pattern" 2>/dev/null)
    fi
}

# Collect cleanable items based on analysis mode
(
    if [ "$ANALYSIS_MODE" = "folders" ] || [ "$ANALYSIS_MODE" = "both" ]; then
        # Development artifact folders
        find_cleanable_folders "node_modules" >> "$CLEANABLE_TEMP"
        find_cleanable_folders ".next" >> "$CLEANABLE_TEMP"
        find_cleanable_folders "dist" >> "$CLEANABLE_TEMP"
        find_cleanable_folders "__pycache__" 10 >> "$CLEANABLE_TEMP"
        find_cleanable_folders "venv" >> "$CLEANABLE_TEMP"
        find_cleanable_folders ".venv" >> "$CLEANABLE_TEMP"
        find_cleanable_folders ".pytest_cache" 10 >> "$CLEANABLE_TEMP"
        find_cleanable_folders "vendor" >> "$CLEANABLE_TEMP"
        find_cleanable_folders ".gems" >> "$CLEANABLE_TEMP"
        find_cleanable_folders ".bundle" >> "$CLEANABLE_TEMP"

        # vendor/bundle (special path)
        for user_dir in /Users/*; do
            if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
                if [ -d "$user_dir/vendor/bundle" ]; then
                    local size_kb
                    if [ "$EUID" -eq 0 ]; then
                        size_kb=$(sudo du -sk "$user_dir/vendor/bundle" 2>/dev/null | cut -f1)
                        size_human=$(sudo du -sh "$user_dir/vendor/bundle" 2>/dev/null | awk '{print $1}')
                    else
                        size_kb=$(du -sk "$user_dir/vendor/bundle" 2>/dev/null | cut -f1)
                        size_human=$(du -sh "$user_dir/vendor/bundle" 2>/dev/null | awk '{print $1}')
                    fi
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 100 ]; then
                        echo "$size_kb $size_human $user_dir/vendor/bundle"
                    fi
                fi
            fi
        done >> "$CLEANABLE_TEMP"

        # Cache folders
        for user_dir in /Users/*; do
            if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
                if [ -d "$user_dir/Library/Caches" ]; then
                    local size_kb
                    if [ "$EUID" -eq 0 ]; then
                        size_kb=$(sudo du -sk "$user_dir/Library/Caches" 2>/dev/null | cut -f1)
                        size_human=$(sudo du -sh "$user_dir/Library/Caches" 2>/dev/null | awk '{print $1}')
                    else
                        size_kb=$(du -sk "$user_dir/Library/Caches" 2>/dev/null | cut -f1)
                        size_human=$(du -sh "$user_dir/Library/Caches" 2>/dev/null | awk '{print $1}')
                    fi
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
                        echo "$size_kb $size_human $user_dir/Library/Caches"
                    fi
                fi
            fi
        done >> "$CLEANABLE_TEMP"

        # Trash folders
        for user_dir in /Users/*; do
            if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
                if [ -d "$user_dir/.Trash" ]; then
                    local size_kb
                    if [ "$EUID" -eq 0 ]; then
                        size_kb=$(sudo du -sk "$user_dir/.Trash" 2>/dev/null | cut -f1)
                        size_human=$(sudo du -sh "$user_dir/.Trash" 2>/dev/null | awk '{print $1}')
                    else
                        size_kb=$(du -sk "$user_dir/.Trash" 2>/dev/null | cut -f1)
                        size_human=$(du -sh "$user_dir/.Trash" 2>/dev/null | awk '{print $1}')
                    fi
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
                        echo "$size_kb $size_human $user_dir/.Trash"
                    fi
                fi
            fi
        done >> "$CLEANABLE_TEMP"

        # Xcode DerivedData (macOS only)
        for user_dir in /Users/*; do
            if [ -d "$user_dir" ] && [ "$user_dir" != "/Users/Shared" ]; then
                if [ -d "$user_dir/Library/Developer/Xcode/DerivedData" ]; then
                    local size_kb
                    if [ "$EUID" -eq 0 ]; then
                        size_kb=$(sudo du -sk "$user_dir/Library/Developer/Xcode/DerivedData" 2>/dev/null | cut -f1)
                        size_human=$(sudo du -sh "$user_dir/Library/Developer/Xcode/DerivedData" 2>/dev/null | awk '{print $1}')
                    else
                        size_kb=$(du -sk "$user_dir/Library/Developer/Xcode/DerivedData" 2>/dev/null | cut -f1)
                        size_human=$(du -sh "$user_dir/Library/Developer/Xcode/DerivedData" 2>/dev/null | awk '{print $1}')
                    fi
                    if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
                        echo "$size_kb $size_human $user_dir/Library/Developer/Xcode/DerivedData"
                    fi
                fi
            fi
        done >> "$CLEANABLE_TEMP"
    fi

    if [ "$ANALYSIS_MODE" = "files" ] || [ "$ANALYSIS_MODE" = "both" ]; then
        # Cleanable files: logs, temporary files, etc.
        find_cleanable_files "*.log" 1048576 >> "$CLEANABLE_TEMP"  # Logs > 1MB
        find_cleanable_files "*.tmp" 1048576 >> "$CLEANABLE_TEMP"   # Temp files > 1MB
        find_cleanable_files "*.cache" 1048576 >> "$CLEANABLE_TEMP" # Cache files > 1MB
        find_cleanable_files "*.pyc" 1048576 >> "$CLEANABLE_TEMP"  # Python compiled > 1MB
        find_cleanable_files "*.pyo" 1048576 >> "$CLEANABLE_TEMP"   # Python optimized > 1MB
        find_cleanable_files "*.swp" 0 >> "$CLEANABLE_TEMP"         # Vim swap files
        find_cleanable_files "*.swo" 0 >> "$CLEANABLE_TEMP"         # Vim swap files
        find_cleanable_files ".DS_Store" 0 >> "$CLEANABLE_TEMP"     # macOS DS_Store files

        # Old log files in system locations
        if [ "$EUID" -eq 0 ]; then
            sudo find /var/log -type f -name "*.log" -size +10M 2>/dev/null | while read -r logfile; do
                size_kb=$(sudo du -sk "$logfile" 2>/dev/null | cut -f1)
                size_human=$(sudo du -sh "$logfile" 2>/dev/null | awk '{print $1}')
                if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
                    echo "$size_kb $size_human $logfile"
                fi
            done >> "$CLEANABLE_TEMP"
        fi
    fi
) &
COLLECT_PID=$!
show_progress "$COLLECT_PID" "  Collecting cleanable items"
wait "$COLLECT_PID" 2>/dev/null

# Group and aggregate by item name
if [ -s "$CLEANABLE_TEMP" ]; then
    echo ""
    if [ "$ANALYSIS_MODE" = "folders" ]; then
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${MAGENTA}🧹 CLEANABLE FOLDERS (Sorted by Total Size)${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    elif [ "$ANALYSIS_MODE" = "files" ]; then
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${MAGENTA}🧹 CLEANABLE FILES (Sorted by Total Size)${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${MAGENTA}🧹 CLEANABLE ITEMS (Sorted by Total Size)${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    echo ""

    # Group by item name (last component of path) and sum sizes
    GROUPED_TEMP=$(mktemp)
    awk '{
        path = $3
        # Extract item name (last component of path)
        n = split(path, parts, "/")
        item_name = parts[n]

        # Special handling for paths that should be grouped by their relative path
        # e.g., Library/Caches, .Trash, vendor/bundle, Library/Developer/Xcode/DerivedData
        if (path ~ /\/Library\/Caches$/) {
            item_name = "Library/Caches"
        } else if (path ~ /\/\.Trash$/) {
            item_name = ".Trash"
        } else if (path ~ /\/vendor\/bundle$/) {
            item_name = "vendor/bundle"
        } else if (path ~ /\/Library\/Developer\/Xcode\/DerivedData$/) {
            item_name = "Xcode/DerivedData"
        } else if (path ~ /\/\.cache$/) {
            item_name = ".cache"
        } else if (path ~ /\/\.local\/share\/Trash$/) {
            item_name = ".local/share/Trash"
        }

        # Sum sizes and count occurrences
        if (item_name in total_size) {
            total_size[item_name] += $1
            count[item_name] += 1
        } else {
            total_size[item_name] = $1
            count[item_name] = 1
        }
    }
    END {
        # Output: total_size_kb item_name count
        for (item in total_size) {
            printf "%d %s %d\n", total_size[item], item, count[item]
        }
    }' "$CLEANABLE_TEMP" > "$GROUPED_TEMP"

    # Sort by total size and display
    total_groups=$(wc -l < "$GROUPED_TEMP" | tr -d ' ')
    threshold1=$((total_groups / 5))
    threshold2=$((total_groups / 2))

    sort -rn "$GROUPED_TEMP" | nl -w3 -s' ' | while IFS= read -r line; do
        num=$(echo "$line" | awk '{print $1}')
        total_size_kb=$(echo "$line" | awk '{print $2}')
        item_name=$(echo "$line" | awk '{print $3}')
        count=$(echo "$line" | awk '{print $4}')

        # Convert to human readable
        if [ "$total_size_kb" -ge 1048576 ]; then
            size_gb=$((total_size_kb / 1048576))
            size_mb=$(((total_size_kb % 1048576) / 1024))
            if [ "$size_mb" -gt 0 ]; then
                size_human="${size_gb}.$((size_mb / 100))G"
            else
                size_human="${size_gb}G"
            fi
        elif [ "$total_size_kb" -ge 1024 ]; then
            size_mb=$((total_size_kb / 1024))
            size_kb=$((total_size_kb % 1024))
            if [ "$size_kb" -gt 0 ]; then
                size_human="${size_mb}.$((size_kb / 10))M"
            else
                size_human="${size_mb}M"
            fi
        else
            size_human="${total_size_kb}K"
        fi

        if [ "$count" -eq 1 ]; then
            item_display="$item_name"
        else
            item_display="$item_name ($count folders)"
        fi

        if [ "$num" -le "$threshold1" ]; then
            printf "${RED}${BOLD}%3s.${NC} ${YELLOW}%-10s${NC} %s\n" "$num" "$size_human" "$item_display"
        elif [ "$num" -le "$threshold2" ]; then
            printf "${YELLOW}%3s.${NC} ${GREEN}%-10s${NC} %s\n" "$num" "$size_human" "$item_display"
        else
            printf "${BLUE}%3s.${NC} %-10s %s\n" "$num" "$size_human" "$item_display"
        fi
    done

    rm -f "$GROUPED_TEMP"
else
    echo -e "${GREEN}${BOLD}  ✨ System is clean! No cleanup needed.${NC}"
fi

# Show Docker info separately if applicable
if [ "$DOCKER_STATUS" = "Running" ] && ([ "$DOCKER_CONTAINERS" -gt 0 ] || [ "$DOCKER_IMAGES" -gt 0 ] || [ "$DOCKER_VOLUMES" -gt 0 ]); then
    echo ""
    echo -e "${BOLD}${YELLOW}🐳 Docker Resources:${NC}"
    echo -e "  ${BLUE}Containers:${NC} ${DOCKER_CONTAINERS}"
    echo -e "  ${BLUE}Images:${NC} ${DOCKER_IMAGES}"
    echo -e "  ${BLUE}Volumes:${NC} ${DOCKER_VOLUMES}"
fi

echo ""

echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                    ✅  ANALYSIS COMPLETE!  ✅                  ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}💡 ${BOLD}Tip:${NC} Run ${CYAN}./clean_space.sh${NC} to free up space${NC}"
echo ""
