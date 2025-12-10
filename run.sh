#!/usr/bin/env bash

#
# Rubinho Clean OS - Main Entry Point
#
# Simplified interface for disk space analysis and cleanup.
# Automatically detects platform and provides two core options:
#   1. Analyze disk space
#   2. Clean up unnecessary files
#

set -eo pipefail

# ────────────────────────────────────────────────────────────────
# Script Directory and Initialization
# ────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command-line arguments
FORCE_MODE=false
VERBOSE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE_MODE=true
            export LOG_LEVEL="DEBUG"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--force] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --force       Skip all confirmation prompts"
            echo "  --verbose, -v Enable verbose logging (DEBUG level)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Export modes for use in other scripts
export FORCE_MODE
export VERBOSE_MODE

# ────────────────────────────────────────────────────────────────
# Platform Detection
# ────────────────────────────────────────────────────────────────

# Source platform detection module
if [ ! -f "$SCRIPT_DIR/lib/platform.sh" ]; then
    echo "ERROR: Platform detection module not found at $SCRIPT_DIR/lib/platform.sh"
    exit 1
fi

# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"

# ────────────────────────────────────────────────────────────────
# Logging Initialization
# ────────────────────────────────────────────────────────────────

# Source logging module
if [ ! -f "$SCRIPT_DIR/lib/logging.sh" ]; then
    echo "WARNING: Logging module not found at $SCRIPT_DIR/lib/logging.sh" >&2
else
    # shellcheck source=lib/logging.sh
    source "$SCRIPT_DIR/lib/logging.sh"
    init_logging
    log_info "Rubinho Clean OS started"
    log_info "Platform: $PLATFORM_NAME"
    log_info "Force mode: $FORCE_MODE"
    log_info "Verbose mode: $VERBOSE_MODE"
fi

# ────────────────────────────────────────────────────────────────
# Welcome Banner
# ────────────────────────────────────────────────────────────────

# Clear screen if possible (works in most terminals)
if command -v clear &>/dev/null && [ -t 0 ]; then
    clear
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         🧹 Rubinho Clean OS - Disk Space Manager 🧹            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_platform_info
echo ""

# ────────────────────────────────────────────────────────────────
# Handler Functions
# ────────────────────────────────────────────────────────────────

analyze_disk() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Analyze Disk Space"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This will analyze your disk usage and show:"
    echo "  • Top largest folders and files (configurable)"
    echo "  • Per-user breakdown (caches, trash, logs, etc.)"
    echo "  • Development artifacts count (node_modules, .next, etc.)"
    echo "  • Disk space summary with capacity and usage"
    echo ""

    # Determine platform-specific script path
    local analyze_script
    if is_macos; then
        analyze_script="$SCRIPT_DIR/macos/scripts/utils/analyze_space.sh"
    elif is_linux; then
        analyze_script="$SCRIPT_DIR/linux/scripts/utils/analyze_space.sh"
    else
        echo "❌ Error: Unsupported platform: $PLATFORM_NAME"
        log_error "Unsupported platform: $PLATFORM_NAME"
        return 1
    fi

    # Validate script exists
    if [ ! -f "$analyze_script" ]; then
        echo "❌ Error: Analysis script not found at: $analyze_script"
        log_error "Analysis script not found: $analyze_script"
        return 1
    fi

    # Make script executable
    chmod +x "$analyze_script" 2>/dev/null || true

    echo "🔍 Starting disk analysis..."
    echo ""
    log_info "Starting disk analysis: $analyze_script"

    # Execute analysis script
    if bash "$analyze_script"; then
        log_info "Disk analysis completed"
    else
        echo ""
        echo "❌ Disk analysis failed. Check the logs for details."
        log_error "Disk analysis failed"
        return 1
    fi
}

cleanup_files() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧹 Clean Up Disk Space"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This will clean up unnecessary files:"
    echo "  • Docker containers, images, volumes"
    echo "  • Development artifacts (node_modules, build files, etc.)"
    echo "  • Application caches"
    echo "  • Trash contents"
    echo "  • Old logs and temporary files"
    echo ""
    echo "⚠️  WARNING: This will remove development files!"
    echo "   Projects will need to reinstall dependencies after cleanup."
    echo ""

    if [ "$FORCE_MODE" = false ]; then
        read -p "Continue with cleanup? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cleanup cancelled."
            log_info "User cancelled cleanup"
            return 0
        fi
    fi

    # Determine platform-specific script path
    local cleanup_script
    if is_macos; then
        cleanup_script="$SCRIPT_DIR/macos/scripts/utils/clean_space.sh"
    elif is_linux; then
        cleanup_script="$SCRIPT_DIR/linux/scripts/utils/clean_space.sh"
    else
        echo "❌ Error: Unsupported platform: $PLATFORM_NAME"
        log_error "Unsupported platform: $PLATFORM_NAME"
        return 1
    fi

    # Validate script exists
    if [ ! -f "$cleanup_script" ]; then
        echo "❌ Error: Cleanup script not found at: $cleanup_script"
        log_error "Cleanup script not found: $cleanup_script"
        return 1
    fi

    # Make script executable
    chmod +x "$cleanup_script" 2>/dev/null || true

    echo ""
    echo "🧹 Starting cleanup..."
    echo ""
    log_info "Starting cleanup: $cleanup_script"

    # Execute cleanup script
    if bash "$cleanup_script"; then
        echo ""
        echo "✅ Cleanup completed successfully!"
        log_info "Cleanup completed successfully"
    else
        echo ""
        echo "❌ Cleanup failed. Check the logs for details."
        log_error "Cleanup failed"
        return 1
    fi
}

# ────────────────────────────────────────────────────────────────
# Main Menu
# ────────────────────────────────────────────────────────────────

main_menu() {
    while true; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "What would you like to do?"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  1) 📊 Analyze disk space"
        echo "     Show what's taking up space on your system"
        echo ""
        echo "  2) 🧹 Clean up unnecessary files"
        echo "     Remove caches, temporary files, and development artifacts"
        echo ""
        echo "  0) ❌ Exit"
        echo ""

        # Read user choice
        read -p "Enter your choice [0-2]: " choice
        echo ""

        case $choice in
            1)
                analyze_disk
                ;;
            2)
                cleanup_files
                ;;
            0)
                echo "Goodbye!"
                log_info "User selected exit"
                finalize_logging
                print_log_location
                exit 0
                ;;
            *)
                echo "❌ Invalid choice. Please enter a number between 0 and 2."
                log_warning "Invalid menu choice: $choice"
                echo ""
                ;;
        esac

        # Ask if user wants to do something else
        if [ "$FORCE_MODE" = false ]; then
            echo ""
            read -p "Do you want to perform another action? [Y/n]: " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo "Goodbye!"
                log_info "User chose not to continue"
                finalize_logging
                print_log_location
                exit 0
            fi
            echo ""
        else
            # In force mode, exit after completing one action
            echo "Force mode: Exiting after completing action."
            log_info "Force mode: exiting after action"
            finalize_logging
            print_log_location
            exit 0
        fi
    done
}

# ────────────────────────────────────────────────────────────────
# Cleanup Handler
# ────────────────────────────────────────────────────────────────

cleanup_and_exit() {
    local exit_code=$?
    echo ""
    log_info "Script exiting with code: $exit_code"
    finalize_logging
    print_log_location
    exit "$exit_code"
}

# ────────────────────────────────────────────────────────────────
# Entry Point
# ────────────────────────────────────────────────────────────────

# Trap signals for graceful exit
trap 'echo ""; echo "Interrupted by user. Exiting..."; log_warning "Script interrupted by user (Ctrl+C)"; cleanup_and_exit' INT
trap cleanup_and_exit EXIT

# Start main menu
main_menu
