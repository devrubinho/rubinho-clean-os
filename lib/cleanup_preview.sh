#!/usr/bin/env bash

#
# Cleanup Preview Module
#
# Provides detailed cleanup preview system that displays what will be deleted
# before any destructive operations, with per-category confirmation prompts.
#
# Usage:
#   source lib/cleanup_preview.sh
#   cleanup_files_interactive
#

set -eo pipefail

# Ensure platform detection is available
if [ -z "$PLATFORM" ]; then
    echo "ERROR: Platform detection must be sourced before cleanup preview" >&2
    return 1 2>/dev/null || exit 1
fi

# Ensure logging is available
if ! command -v log_info >/dev/null 2>&1; then
    echo "ERROR: Logging module must be sourced before cleanup preview" >&2
    return 1 2>/dev/null || exit 1
fi

# ────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────

# Minimum age in days for files to be considered old
export CLEANUP_OLD_FILE_DAYS=30

# Maximum number of example files to show per category
export CLEANUP_EXAMPLE_COUNT=5

# ────────────────────────────────────────────────────────────────
# Platform-Specific Cleanup Categories
# ────────────────────────────────────────────────────────────────

get_cleanup_categories() {
    if is_macos; then
        # macOS categories: Name|Path|Age|Description
        echo "User Caches|\$HOME/Library/Caches|0|Application cache files (safe to delete, apps will recreate)"
        echo "Homebrew Cache|\$HOME/Library/Caches/Homebrew|0|Homebrew package cache (safe to delete, can redownload)"
        echo "npm Cache|\$HOME/.npm/_cacache|0|npm package cache (safe to delete, can redownload)"
        echo "Old Downloads|\$HOME/Downloads|$CLEANUP_OLD_FILE_DAYS|Downloads older than $CLEANUP_OLD_FILE_DAYS days"
        echo "User Logs|\$HOME/Library/Logs|7|Application log files older than 7 days"
        echo "Trash|\$HOME/.Trash|0|Items in Trash (will be permanently deleted)"
    elif is_linux; then
        # Linux categories: Name|Path|Age|Description
        echo "User Caches|\$HOME/.cache|0|Application cache files (safe to delete, apps will recreate)"
        echo "Temp Files|/tmp|1|Temporary files older than 1 day in /tmp"
        echo "npm Cache|\$HOME/.npm/_cacache|0|npm package cache (safe to delete, can redownload)"
        echo "Old Downloads|\$HOME/Downloads|$CLEANUP_OLD_FILE_DAYS|Downloads older than $CLEANUP_OLD_FILE_DAYS days"
        echo "User Logs|\$HOME/.local/share/logs|7|Application log files older than 7 days"
        echo "Trash|\$HOME/.local/share/Trash|0|Items in Trash (will be permanently deleted)"
    else
        # Generic categories
        echo "Temp Files|/tmp|1|Temporary files older than 1 day"
        echo "Old Downloads|\$HOME/Downloads|$CLEANUP_OLD_FILE_DAYS|Downloads older than $CLEANUP_OLD_FILE_DAYS days"
    fi
}

# ────────────────────────────────────────────────────────────────
# Utility Functions
# ────────────────────────────────────────────────────────────────

# Format bytes (reuse from disk_analysis.sh)
format_bytes() {
    local bytes=$1

    if [ -z "$bytes" ] || ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return
    fi

    if [ "$bytes" -ge 1073741824 ]; then
        echo "$((bytes / 1073741824))GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$((bytes / 1048576))MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

# ────────────────────────────────────────────────────────────────
# Category Scanning
# ────────────────────────────────────────────────────────────────

scan_cleanup_category() {
    local category_name="$1"
    local path_template="$2"
    local age_days="$3"
    local description="$4"

    # Expand path variables
    local path
    eval "path=\"$path_template\""

    # Check if path exists
    if [ ! -e "$path" ]; then
        echo "0|0"
        return
    fi

    # Temporary file for results
    local temp_file="/tmp/cleanup_scan_$$_${category_name//[^a-zA-Z0-9]/_}.txt"
    rm -f "$temp_file"

    # Build find command based on age
    if [ "$age_days" -gt 0 ]; then
        find "$path" -type f -mtime "+$age_days" 2>/dev/null | while read -r file; do
            if [ -f "$file" ]; then
                local size_bytes
                size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                if [[ "$size_bytes" =~ ^[0-9]+$ ]] && [ "$size_bytes" -gt 0 ]; then
                    echo "$file|$size_bytes" >> "$temp_file"
                fi
            fi
        done
    else
        find "$path" -type f 2>/dev/null | while read -r file; do
            if [ -f "$file" ]; then
                local size_bytes
                size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                if [[ "$size_bytes" =~ ^[0-9]+$ ]] && [ "$size_bytes" -gt 0 ]; then
                    echo "$file|$size_bytes" >> "$temp_file"
                fi
            fi
        done
    fi

    # Calculate totals
    local file_count=0
    local total_bytes=0

    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        file_count=$(wc -l < "$temp_file" | tr -d ' ')
        total_bytes=$(awk -F'|' '{sum+=$2} END {print sum+0}' "$temp_file")
    fi

    # Clean up temp file
    rm -f "$temp_file"

    # Output: file_count|total_bytes
    echo "${file_count:-0}|${total_bytes:-0}"
}

# ────────────────────────────────────────────────────────────────
# Preview Display
# ────────────────────────────────────────────────────────────────

show_cleanup_preview() {
    local category_name="$1"
    local path_template="$2"
    local age_days="$3"
    local description="$4"
    local file_count="$5"
    local total_bytes="$6"

    # Expand path for display
    local path
    eval "path=\"$path_template\""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$category_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Description: $description"
    echo "Location: $path"
    if [ "$age_days" -gt 0 ]; then
        echo "Age filter: Files older than $age_days days"
    fi
    echo ""
    echo "Files to delete: $file_count"
    echo "Space to free: $(format_bytes "$total_bytes")"
    echo ""
}

# ────────────────────────────────────────────────────────────────
# Deletion Functions
# ────────────────────────────────────────────────────────────────

delete_category_files() {
    local path_template="$1"
    local age_days="$2"

    # Expand path variables
    local path
    eval "path=\"$path_template\""

    # Check if path exists
    if [ ! -e "$path" ]; then
        return 0
    fi

    # Delete files based on age
    if [ "$age_days" -gt 0 ]; then
        find "$path" -type f -mtime "+$age_days" -delete 2>/dev/null || true
    else
        find "$path" -type f -delete 2>/dev/null || true
    fi

    # Clean up empty directories
    find "$path" -type d -empty -delete 2>/dev/null || true
}

# ────────────────────────────────────────────────────────────────
# Main Cleanup Function
# ────────────────────────────────────────────────────────────────

cleanup_files_interactive() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧹 Clean Up Unnecessary Files"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This will scan your system for unnecessary files that can be safely deleted."
    echo "You will be asked to confirm each category before deletion."
    echo ""

    if [ "$FORCE_MODE" = false ]; then
        read -p "Continue with cleanup? [y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cleanup cancelled."
            log_info "User cancelled cleanup"
            return 0
        fi
    fi

    echo ""
    echo "Scanning filesystem..."
    echo ""

    # Track totals
    local total_space_freed=0
    local total_files_deleted=0

    # Process each category
    while IFS='|' read -r category_name path_template age_days description; do
        # Scan category
        local scan_result
        scan_result=$(scan_cleanup_category "$category_name" "$path_template" "$age_days" "$description")

        # Parse results
        local file_count
        local total_bytes
        file_count=$(echo "$scan_result" | cut -d'|' -f1)
        total_bytes=$(echo "$scan_result" | cut -d'|' -f2)

        # Skip if nothing to clean
        if [ -z "$file_count" ] || [ "$file_count" -eq 0 ]; then
            continue
        fi

        # Show preview
        show_cleanup_preview "$category_name" "$path_template" "$age_days" "$description" "$file_count" "$total_bytes"

        # Ask for confirmation
        local should_delete=false
        if [ "$FORCE_MODE" = true ]; then
            should_delete=true
            echo "Force mode: Deleting without confirmation..."
        else
            read -p "Delete these files? [y/N]: " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                should_delete=true
            fi
        fi

        # Delete if confirmed
        if [ "$should_delete" = true ]; then
            echo "Deleting files..."
            log_info "Deleting category: $category_name ($file_count files, $(format_bytes "$total_bytes"))"

            delete_category_files "$path_template" "$age_days"

            echo "✓ Deleted $file_count files, freed $(format_bytes "$total_bytes")"
            log_info "Deleted $file_count files from $category_name"

            total_files_deleted=$((total_files_deleted + file_count))
            total_space_freed=$((total_space_freed + total_bytes))
        else
            echo "Skipped."
            log_info "User skipped category: $category_name"
        fi

        echo ""
    done < <(get_cleanup_categories)

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cleanup Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total files deleted: $total_files_deleted"
    echo "Total space freed: $(format_bytes "$total_space_freed")"
    echo ""
    log_info "Cleanup completed: $total_files_deleted files deleted, $(format_bytes "$total_space_freed") freed"
}

# Export functions for use in other scripts
export -f get_cleanup_categories
export -f format_bytes
export -f scan_cleanup_category
export -f show_cleanup_preview
export -f delete_category_files
export -f cleanup_files_interactive
