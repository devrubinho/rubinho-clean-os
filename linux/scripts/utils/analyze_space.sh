#!/bin/bash

# analyze_space.sh
# Analyzes disk space usage on Linux by finding the largest
# folders and files, with per-user breakdown and visual rankings
# Usage: 
#   sudo ./analyze_space.sh   - Recommended for full system access
#   ./analyze_space.sh        - Limited to current user

# ────────────────────────────────
# System Check
# ────────────────────────────────

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ Error: This script only works on Linux"
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
# User Configuration
# ────────────────────────────────

# Default number of items to analyze
DEFAULT_ITEMS=50

# Ask user for number of items
echo ""
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
echo -e "${BOLD}${CYAN}║         📊  DISK SPACE ANALYSIS - TOP ${NUM_ITEMS} ITEMS  📊$(printf '%*s' $((13 - ${#NUM_ITEMS})) '')║${NC}"
echo -e "${BOLD}${CYAN}║                                                                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ────────────────────────────────
# Privilege Check
# ────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  For complete system analysis, run with sudo:${NC}"
    echo -e "${YELLOW}   sudo ./analyze_space.sh${NC}"
    echo ""
    echo -e "${BLUE}   Running limited analysis (only accessible areas)...${NC}"
    echo ""
else
    echo -e "${GREEN}✓ Running with administrator privileges${NC}"
    echo -e "${BLUE}  Full system analysis will be performed${NC}"
    echo ""
fi

# ────────────────────────────────
# Target Directory Selection
# ────────────────────────────────

TARGET="/"

echo -e "${BOLD}${MAGENTA}🔍 Analyzing: $TARGET${NC}"
echo -e "${YELLOW}⏳ This may take a few minutes... Please wait.${NC}"
echo ""

# ────────────────────────────────
# Temporary File Setup
# ────────────────────────────────

TEMP_DIRS=$(mktemp)
TEMP_FILES=$(mktemp)

cleanup() {
    rm -f "$TEMP_DIRS" "$TEMP_FILES" 2>/dev/null
}
trap cleanup EXIT

# ────────────────────────────────
# Data Collection (Optimized)
# ────────────────────────────────

echo -e "${BLUE}📂 Finding largest directories...${NC}"
# Use find with maxdepth to get top-level directories first, then du on each
# Get more results than needed for better sorting
SEARCH_LIMIT=$((NUM_ITEMS * 3))
find "$TARGET" -maxdepth 3 -type d 2>/dev/null | while read -r dir; do
    du -shx "$dir" 2>/dev/null
done | sort -rh | head -n $SEARCH_LIMIT > "$TEMP_DIRS" &
DIR_PID=$!

echo -e "${BLUE}📄 Finding largest files...${NC}"
# Find large files directly (over 100MB to speed things up)
find "$TARGET" -type f -size +100M 2>/dev/null -exec du -h {} \; | sort -rh | head -n $SEARCH_LIMIT > "$TEMP_FILES" &
FILE_PID=$!

# Wait for both processes to complete
wait $DIR_PID 2>/dev/null
wait $FILE_PID 2>/dev/null

echo -e "${GREEN}✓ Collection complete!${NC}"
echo ""

# ────────────────────────────────
# Display Top N Largest Folders
# ────────────────────────────────

echo -e "${BLUE}🔄 Processing results...${NC}"
echo ""
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

# ────────────────────────────────
# Display Top N Largest Files
# ────────────────────────────────

echo ""
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

# ────────────────────────────────
# Per-User Analysis with Cleanable Items
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         👥  USER ANALYSIS & CLEANUP OPPORTUNITIES  👥        ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

format_size() {
    local dir=$1
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

# Function to count non-empty folders per user
count_folders_user() {
    local user_dir=$1
    local pattern=$2
    local min_size=${3:-100}
    local count=0
    
    if [ "$EUID" -eq 0 ]; then
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size" ] && [ "$size" -gt "$min_size" ]; then
                    count=$((count + 1))
                fi
            fi
        done < <(sudo find "$user_dir" -type d -name "$pattern" 2>/dev/null)
    else
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size=$(du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size" ] && [ "$size" -gt "$min_size" ]; then
                    count=$((count + 1))
                fi
            fi
        done < <(find "$user_dir" -type d -name "$pattern" 2>/dev/null)
    fi
    
    echo "$count"
}

for user_dir in /home/*; do
    if [ -d "$user_dir" ]; then
        username=$(basename "$user_dir")
        
        # Count development artifacts per user
        node_count=$(count_folders_user "$user_dir" "node_modules")
        next_count=$(count_folders_user "$user_dir" ".next")
        dist_count=$(count_folders_user "$user_dir" "dist")
        pycache_count=$(count_folders_user "$user_dir" "__pycache__" 10)
        venv_count=$(count_folders_user "$user_dir" "venv")
        pytest_count=$(count_folders_user "$user_dir" ".pytest_cache" 10)
        vendor_count=$(count_folders_user "$user_dir" "vendor")
        bin_count=$(count_folders_user "$user_dir" "bin")
        obj_count=$(count_folders_user "$user_dir" "obj")
        
        # Calculate total cleanable items
        total_cleanable=$((node_count + next_count + dist_count + pycache_count + venv_count + pytest_count + vendor_count + bin_count + obj_count))
        
        user_size=$(format_size "$user_dir")
        caches_size=$(format_size "$user_dir/.cache")
        trash_size=$(format_size "$user_dir/.local/share/Trash")
        logs_size=$(format_size "$user_dir/.local/share/logs")
        
        echo -e "${BOLD}${MAGENTA}┌─ ${YELLOW}👤 $username${NC} ${MAGENTA}──────────────────────────────────────────────────────────┐${NC}"
        printf "${BOLD}${MAGENTA}│${NC}  ${GREEN}📁 Home:${NC} %-12s ${CYAN}💾 Caches:${NC} %-10s ${BLUE}📝 Logs:${NC} %-10s ${MAGENTA}│${NC}\n" "$user_size" "$caches_size" "$logs_size"
        
        if [ "$trash_size" != "0B" ]; then
            printf "${BOLD}${MAGENTA}│${NC}  ${RED}🗑️  Trash:${NC} %-10s" "$trash_size"
        else
            printf "${BOLD}${MAGENTA}│${NC}  ${GREEN}🗑️  Trash:${NC} ${GREEN}Empty${NC}"
        fi
        
        if [ $total_cleanable -gt 0 ]; then
            printf " ${YELLOW}🧹 Cleanable:${NC} ${RED}${BOLD}$total_cleanable${NC} items${NC} ${MAGENTA}│${NC}\n"
        else
            printf " ${GREEN}🧹 Cleanable:${NC} ${GREEN}${BOLD}None${NC} ${GREEN}✓${NC} ${MAGENTA}│${NC}\n"
        fi
        
        if [ $total_cleanable -gt 0 ]; then
            echo -e "${BOLD}${MAGENTA}│${NC}"
            echo -e "${BOLD}${MAGENTA}│${NC}  ${BOLD}${CYAN}Development Artifacts:${NC}"
            
            if [ "$node_count" -gt 0 ] || [ "$next_count" -gt 0 ] || [ "$dist_count" -gt 0 ]; then
                js_items=""
                [ "$node_count" -gt 0 ] && js_items="${js_items}📦${node_count} "
                [ "$next_count" -gt 0 ] && js_items="${js_items}⚡${next_count} "
                [ "$dist_count" -gt 0 ] && js_items="${js_items}📁${dist_count} "
                printf "${BOLD}${MAGENTA}│${NC}    ${BLUE}JS/TS:${NC} %-45s ${MAGENTA}│${NC}\n" "$js_items"
            fi
            
            if [ "$pycache_count" -gt 0 ] || [ "$venv_count" -gt 0 ] || [ "$pytest_count" -gt 0 ]; then
                py_items=""
                [ "$pycache_count" -gt 0 ] && py_items="${py_items}🐍${pycache_count} "
                [ "$venv_count" -gt 0 ] && py_items="${py_items}📦${venv_count} "
                [ "$pytest_count" -gt 0 ] && py_items="${py_items}🧪${pytest_count} "
                printf "${BOLD}${MAGENTA}│${NC}    ${BLUE}Python:${NC} %-43s ${MAGENTA}│${NC}\n" "$py_items"
            fi
            
            if [ "$vendor_count" -gt 0 ]; then
                printf "${BOLD}${MAGENTA}│${NC}    ${BLUE}Go:${NC} 🔷${vendor_count} %-47s ${MAGENTA}│${NC}\n" ""
            fi
            
            if [ "$bin_count" -gt 0 ] || [ "$obj_count" -gt 0 ]; then
                dotnet_items=""
                [ "$bin_count" -gt 0 ] && dotnet_items="${dotnet_items}💎bin:${bin_count} "
                [ "$obj_count" -gt 0 ] && dotnet_items="${dotnet_items}💎obj:${obj_count} "
                printf "${BOLD}${MAGENTA}│${NC}    ${BLUE}.NET:${NC} %-45s ${MAGENTA}│${NC}\n" "$dotnet_items"
            fi
        fi
        
        echo -e "${BOLD}${MAGENTA}└────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
done

# ────────────────────────────────
# System-wide Statistics
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              📊  SYSTEM-WIDE CLEANUP SUMMARY  📊              ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to count non-empty folders system-wide
count_folders() {
    local pattern=$1
    local min_size=${2:-100}  # Default 100KB minimum
    local count=0
    
    if [ "$EUID" -eq 0 ]; then
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size=$(sudo du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size" ] && [ "$size" -gt "$min_size" ]; then
                    count=$((count + 1))
                fi
            fi
        done < <(sudo find /home -type d -name "$pattern" 2>/dev/null)
    else
        while IFS= read -r path; do
            if [ -d "$path" ]; then
                local size=$(du -sk "$path" 2>/dev/null | cut -f1)
                if [ -n "$size" ] && [ "$size" -gt "$min_size" ]; then
                    count=$((count + 1))
                fi
            fi
        done < <(find /home -type d -name "$pattern" 2>/dev/null)
    fi
    
    echo "$count"
}

# Count all artifacts silently
TOTAL_NODE_MODULES=$(count_folders "node_modules")
TOTAL_NEXT=$(count_folders ".next")
TOTAL_DIST=$(count_folders "dist")
TOTAL_PYCACHE=$(count_folders "__pycache__" 10)
TOTAL_VENV=$(count_folders "venv")
TOTAL_PYTEST=$(count_folders ".pytest_cache" 10)
TOTAL_GO_VENDOR=$(count_folders "vendor")
TOTAL_DOTNET_BIN=$(count_folders "bin")
TOTAL_DOTNET_OBJ=$(count_folders "obj")

# Count cache and trash
TOTAL_CACHE_SIZE=0
for user_dir in /home/*; do
    if [ -d "$user_dir" ]; then
        if [ -d "$user_dir/.cache" ]; then
            cache_size=$(du -sk "$user_dir/.cache" 2>/dev/null | cut -f1)
            if [ -n "$cache_size" ] && [ "$cache_size" -gt 0 ]; then
                TOTAL_CACHE_SIZE=$((TOTAL_CACHE_SIZE + cache_size))
            fi
        fi
    fi
done
TOTAL_CACHE_SIZE_MB=$((TOTAL_CACHE_SIZE / 1024))

TOTAL_TRASH_ITEMS=0
TOTAL_TRASH_SIZE=0
for user_dir in /home/*; do
    if [ -d "$user_dir" ]; then
        if [ -d "$user_dir/.local/share/Trash" ]; then
            trash_count=$(find "$user_dir/.local/share/Trash" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
            trash_size=$(du -sk "$user_dir/.local/share/Trash" 2>/dev/null | cut -f1)
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
TOTAL_DOTNET=$((TOTAL_DOTNET_BIN + TOTAL_DOTNET_OBJ))
TOTAL_ARTIFACTS=$((TOTAL_JS + TOTAL_PY + TOTAL_GO_VENDOR + TOTAL_DOTNET))

# Display results in compact format
echo -e "${BOLD}${YELLOW}📦 Development Artifacts:${NC}"
echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"

if [ $TOTAL_ARTIFACTS -eq 0 ] && [ "$TOTAL_CACHE_SIZE_MB" -eq 0 ] && [ "$TOTAL_TRASH_ITEMS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✨ System is clean! No cleanup needed.${NC}"
    echo ""
else
    if [ $TOTAL_JS -gt 0 ]; then
        js_line="  ${BLUE}JS/TS:${NC}"
        [ "$TOTAL_NODE_MODULES" -gt 0 ] && js_line="${js_line} 📦${TOTAL_NODE_MODULES}"
        [ "$TOTAL_NEXT" -gt 0 ] && js_line="${js_line} ⚡${TOTAL_NEXT}"
        [ "$TOTAL_DIST" -gt 0 ] && js_line="${js_line} 📁${TOTAL_DIST}"
        echo -e "$js_line"
    fi
    
    if [ $TOTAL_PY -gt 0 ]; then
        py_line="  ${BLUE}Python:${NC}"
        [ "$TOTAL_PYCACHE" -gt 0 ] && py_line="${py_line} 🐍${TOTAL_PYCACHE}"
        [ "$TOTAL_VENV" -gt 0 ] && py_line="${py_line} 📦${TOTAL_VENV}"
        [ "$TOTAL_PYTEST" -gt 0 ] && py_line="${py_line} 🧪${TOTAL_PYTEST}"
        echo -e "$py_line"
    fi
    
    if [ "$TOTAL_GO_VENDOR" -gt 0 ]; then
        echo -e "  ${BLUE}Go:${NC} 🔷${TOTAL_GO_VENDOR}"
    fi
    
    if [ $TOTAL_DOTNET -gt 0 ]; then
        dotnet_line="  ${BLUE}.NET:${NC}"
        [ "$TOTAL_DOTNET_BIN" -gt 0 ] && dotnet_line="${dotnet_line} 💎bin:${TOTAL_DOTNET_BIN}"
        [ "$TOTAL_DOTNET_OBJ" -gt 0 ] && dotnet_line="${dotnet_line} 💎obj:${TOTAL_DOTNET_OBJ}"
        echo -e "$dotnet_line"
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}💾 System Data:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    
    if [ "$TOTAL_CACHE_SIZE_MB" -gt 0 ]; then
        echo -e "  💾 Caches: ${YELLOW}${BOLD}${TOTAL_CACHE_SIZE_MB} MB${NC}"
    else
        echo -e "  💾 Caches: ${GREEN}${BOLD}Clean${NC} ✓"
    fi
    
    if [ "$TOTAL_TRASH_ITEMS" -gt 0 ]; then
        echo -e "  🗑️  Trash: ${RED}${BOLD}${TOTAL_TRASH_ITEMS} items${NC}"
    else
        echo -e "  🗑️  Trash: ${GREEN}${BOLD}Empty${NC} ✓"
    fi
    
    echo ""
    echo -e "${BOLD}${YELLOW}🐳 Docker:${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "  Status: ${CYAN}$DOCKER_STATUS${NC}"
    if [ "$DOCKER_STATUS" = "Running" ]; then
        if [ "$DOCKER_CONTAINERS" -gt 0 ] || [ "$DOCKER_IMAGES" -gt 0 ] || [ "$DOCKER_VOLUMES" -gt 0 ]; then
            echo -e "  Containers: ${RED}${BOLD}$DOCKER_CONTAINERS${NC}  Images: ${RED}${BOLD}$DOCKER_IMAGES${NC}  Volumes: ${RED}${BOLD}$DOCKER_VOLUMES${NC}"
        else
            echo -e "  ${GREEN}All clean!${NC} ✓"
        fi
    fi
fi

# ────────────────────────────────
# Summary and Statistics
# ────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    💾  DISK SPACE SUMMARY  💾                 ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get disk info
DISK_INFO=$(df -h / | tail -1)
CAPACITY=$(echo "$DISK_INFO" | awk '{print $2}')
USED=$(echo "$DISK_INFO" | awk '{print $3}')
USED_PCT=$(echo "$DISK_INFO" | awk '{print $5}')
AVAILABLE=$(echo "$DISK_INFO" | awk '{print $4}')

echo -e "${BOLD}${MAGENTA}┌────────────────────────────────────────────────────────────┐${NC}"
printf "${BOLD}${MAGENTA}│${NC}  ${GREEN}📊 Capacity:${NC} %-12s ${YELLOW}📈 Used:${NC} %-10s ${CYAN}✨ Available:${NC} %-10s ${MAGENTA}│${NC}\n" "$CAPACITY" "$USED ($USED_PCT)" "$AVAILABLE"
echo -e "${BOLD}${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

if [ -s "$TEMP_DIRS" ]; then
    TOTAL_DIRS=$(wc -l < "$TEMP_DIRS" | tr -d ' ')
fi
if [ -s "$TEMP_FILES" ]; then
    TOTAL_FILES=$(wc -l < "$TEMP_FILES" | tr -d ' ')
fi

if [ -n "$TOTAL_DIRS" ] || [ -n "$TOTAL_FILES" ]; then
    echo -e "${CYAN}📊 Analyzed: ${BOLD}${TOTAL_DIRS:-0}${NC} directories, ${BOLD}${TOTAL_FILES:-0}${NC} files${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                    ✅  ANALYSIS COMPLETE!  ✅                  ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}💡 ${BOLD}Tip:${NC} Run ${CYAN}./clean_space.sh${NC} to free up space${NC}"
echo ""

