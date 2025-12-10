#!/usr/bin/env bash

#
# Disk Analysis Module
#
# Provides detailed disk space analysis organized by category with
# platform-specific path scanning and intelligent highlighting.
#
# Usage:
#   source lib/disk_analysis.sh
#   analyze_disk_usage
#

set -eo pipefail

# Ensure platform detection is available
if [ -z "$PLATFORM" ]; then
    echo "ERROR: Platform detection must be sourced before disk analysis" >&2
    return 1 2>/dev/null || exit 1
fi

# ────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────

# Threshold for highlighting (percentage of total disk)
export HIGHLIGHT_THRESHOLD=10

# Maximum time for analysis (seconds)
export ANALYSIS_TIMEOUT=10

# ────────────────────────────────────────────────────────────────
# Platform-Specific Category Definitions
# ────────────────────────────────────────────────────────────────

get_disk_categories() {
    if is_macos; then
        echo "User Caches|\$HOME/Library/Caches"
        echo "System Logs|\$HOME/Library/Logs|/var/log"
        echo "Application Support|\$HOME/Library/Application Support"
        echo "Downloads|\$HOME/Downloads"
        echo "Trash|\$HOME/.Trash"
        echo "Homebrew Cache|\$HOME/Library/Caches/Homebrew"
        echo "Node Modules|\$HOME/.npm|\$HOME/.nvm"
        echo "Docker|\$HOME/Library/Containers/com.docker.docker"
        echo "Xcode Derived Data|\$HOME/Library/Developer/Xcode/DerivedData"
        echo "iOS Simulators|\$HOME/Library/Developer/CoreSimulator"
    elif is_linux; then
        echo "User Caches|\$HOME/.cache"
        echo "System Logs|/var/log|\$HOME/.local/share/logs"
        echo "Temp Files|/tmp|/var/tmp"
        echo "Downloads|\$HOME/Downloads"
        echo "Trash|\$HOME/.local/share/Trash"
        echo "Package Caches|/var/cache/apt|/var/cache/dnf|/var/cache/yum"
        echo "Node Modules|\$HOME/.npm|\$HOME/.nvm"
        echo "Docker|/var/lib/docker"
        echo "Snap Packages|/var/lib/snapd"
        echo "Old Kernels|/boot"
    else
        # Generic categories
        echo "User Home|\$HOME"
        echo "Temp Files|/tmp"
        echo "System Logs|/var/log"
        echo "Downloads|\$HOME/Downloads"
    fi
}

# ────────────────────────────────────────────────────────────────
# Utility Functions
# ────────────────────────────────────────────────────────────────

# Get total disk size in bytes
get_total_disk_size() {
    local total_kb
    if is_macos; then
        total_kb=$(df -k / | tail -1 | awk '{print $2}')
    else
        total_kb=$(df -k / | tail -1 | awk '{print $2}')
    fi
    echo "$((total_kb * 1024))"
}

# Convert bytes to human-readable format
format_bytes() {
    local bytes=$1

    # Handle empty or non-numeric input
    if [ -z "$bytes" ] || ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return
    fi

    if [ "$bytes" -ge 1073741824 ]; then
        # GB
        echo "$((bytes / 1073741824))GB"
    elif [ "$bytes" -ge 1048576 ]; then
        # MB
        echo "$((bytes / 1048576))MB"
    elif [ "$bytes" -ge 1024 ]; then
        # KB
        echo "$((bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

# Calculate percentage
calculate_percentage() {
    local part=$1
    local total=$2

    # Handle empty or non-numeric input
    if [ -z "$part" ] || ! [[ "$part" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi
    if [ -z "$total" ] || ! [[ "$total" =~ ^[0-9]+$ ]] || [ "$total" -eq 0 ]; then
        echo "0"
        return
    fi

    echo "$((part * 100 / total))"
}

# ────────────────────────────────────────────────────────────────
# Category Scanning
# ────────────────────────────────────────────────────────────────

scan_category() {
    local category_name="$1"
    shift
    local paths=("$@")

    local total_bytes=0
    local temp_file="/tmp/disk_analysis_$$_${category_name//[^a-zA-Z0-9]/_}.txt"

    # Scan each path in the category
    for path_template in "${paths[@]}"; do
        # Expand variables in path
        local path
        eval "path=\"$path_template\""

        # Skip if path doesn't exist
        if [ ! -e "$path" ]; then
            continue
        fi

        # Get size using du (with timeout if available)
        local size_output
        if command -v timeout >/dev/null 2>&1; then
            size_output=$(timeout "$ANALYSIS_TIMEOUT" du -sk "$path" 2>/dev/null | tail -1 || echo "")
        else
            # No timeout available, just run du normally
            size_output=$(du -sk "$path" 2>/dev/null | tail -1 || echo "")
        fi

        if [ -n "$size_output" ]; then
            local size_kb
            size_kb=$(echo "$size_output" | awk '{print $1}')

            # Validate size_kb is a number
            if [[ "$size_kb" =~ ^[0-9]+$ ]]; then
                local size_bytes=$((size_kb * 1024))
                total_bytes=$((total_bytes + size_bytes))

                # Store path and size for top items
                echo "$size_bytes|$path" >> "$temp_file"
            fi
        fi
    done

    # Output: total_bytes
    echo "$total_bytes"

    # Sort and get top 3 items
    if [ -f "$temp_file" ]; then
        sort -t'|' -k1 -rn "$temp_file" | head -3
        rm -f "$temp_file"
    fi
}

# ────────────────────────────────────────────────────────────────
# Main Analysis Function
# ────────────────────────────────────────────────────────────────

analyze_disk_usage() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Disk Space Analysis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Get overall disk statistics
    echo "Overall Disk Usage:"
    df -h / | tail -1 | awk '{printf "  Total: %s\n  Used: %s (%s)\n  Available: %s\n", $2, $3, $5, $4}'
    echo ""

    # Get total disk size for percentage calculations
    local total_disk_bytes
    total_disk_bytes=$(get_total_disk_size)

    echo "Analyzing categories..."
    echo ""

    # Temporary file to store category results
    local results_file="/tmp/disk_analysis_results_$$.txt"

    # Process each category
    while IFS='|' read -r category_name paths; do
        # Convert paths string to array
        IFS='|' read -ra path_array <<< "$paths"

        # Scan category - captures multiline output
        local scan_output
        scan_output=$(scan_category "$category_name" "${path_array[@]}")

        # First line is the total size
        local size_bytes
        size_bytes=$(echo "$scan_output" | head -1)

        # Skip if empty or zero
        if [ -z "$size_bytes" ] || ! [[ "$size_bytes" =~ ^[0-9]+$ ]] || [ "$size_bytes" -eq 0 ]; then
            continue
        fi

        # Write category result
        echo "$size_bytes|$category_name" >> "$results_file"

        # Store top items in separate file
        echo "$scan_output" | tail -n +2 > "/tmp/disk_analysis_${category_name//[^a-zA-Z0-9]/_}_items_$$.txt"
    done < <(get_disk_categories)

    # Check if we have any results
    if [ ! -f "$results_file" ] || [ ! -s "$results_file" ]; then
        echo "No disk usage data found."
        echo ""
        return
    fi

    # Display results
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Category Breakdown:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Sort and display results
    sort -t'|' -k1 -rn "$results_file" | while IFS='|' read -r size_bytes category_name; do
        # Calculate percentage
        local percentage
        percentage=$(calculate_percentage "$size_bytes" "$total_disk_bytes")

        # Format size
        local formatted_size
        formatted_size=$(format_bytes "$size_bytes")

        # Check if should highlight (>10% of total disk)
        local highlight=""
        if [ -n "$percentage" ] && [ "$percentage" -ge "$HIGHLIGHT_THRESHOLD" ]; then
            highlight="⚠️  "
        fi

        # Display category
        printf "%s%-30s %10s (%2d%%)\n" "$highlight" "$category_name:" "$formatted_size" "$percentage"

        # Show top items if available
        local items_file="/tmp/disk_analysis_${category_name//[^a-zA-Z0-9]/_}_items_$$.txt"
        if [ -f "$items_file" ] && [ -s "$items_file" ]; then
            while IFS='|' read -r item_size item_path; do
                if [ -n "$item_size" ] && [ -n "$item_path" ]; then
                    local item_formatted
                    item_formatted=$(format_bytes "$item_size")
                    printf "  └─ %s (%s)\n" "$item_path" "$item_formatted"
                fi
            done < "$items_file"
        fi
        echo ""
    done

    # Cleanup
    rm -f "$results_file" /tmp/disk_analysis_*_items_$$.txt

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Legend:"
    echo "  ⚠️  = Category using >10% of total disk space"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Export functions for use in other scripts
export -f get_disk_categories
export -f get_total_disk_size
export -f format_bytes
export -f calculate_percentage
export -f scan_category
export -f analyze_disk_usage
