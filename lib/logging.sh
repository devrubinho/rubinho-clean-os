#!/usr/bin/env bash

#
# Logging Module
#
# Provides centralized logging functionality with log levels, rotation,
# and sensitive data sanitization for audit trails and debugging.
#
# Usage:
#   source lib/logging.sh
#   init_logging
#   log_info "Installation started"
#   log_error "Failed to install package"
#

set -eo pipefail

# ────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────

# Log directory and file
export LOG_DIR="$HOME/.rubinho/logs"
export LOG_FILE=""
export LOG_LEVEL="${LOG_LEVEL:-INFO}"  # INFO, WARNING, ERROR, DEBUG

# Log level priority function (higher number = more verbose)
get_log_level_priority() {
    case "$1" in
        ERROR) echo 1 ;;
        WARNING) echo 2 ;;
        INFO) echo 3 ;;
        DEBUG) echo 4 ;;
        *) echo 0 ;;
    esac
}

# ────────────────────────────────────────────────────────────────
# Initialization
# ────────────────────────────────────────────────────────────────

init_logging() {
    # Create log directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo "WARNING: Could not create log directory: $LOG_DIR" >&2
            return 1
        }
    fi

    # Generate timestamped log filename
    local timestamp
    timestamp="$(date '+%Y-%m-%d-%H-%M-%S')"
    export LOG_FILE="$LOG_DIR/run-$timestamp.log"

    # Create log file
    touch "$LOG_FILE" 2>/dev/null || {
        echo "WARNING: Could not create log file: $LOG_FILE" >&2
        return 1
    }

    # Write log header
    {
        echo "════════════════════════════════════════════════════════════════"
        echo "Rubinho Scripts Log"
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Platform: ${PLATFORM:-unknown}"
        echo "Log Level: $LOG_LEVEL"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
    } >> "$LOG_FILE"

    # Rotate old logs
    rotate_logs

    return 0
}

# ────────────────────────────────────────────────────────────────
# Log Rotation
# ────────────────────────────────────────────────────────────────

rotate_logs() {
    # Keep only the last 10 log files
    local log_count
    log_count=$(find "$LOG_DIR" -name "run-*.log" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [ "$log_count" -gt 10 ]; then
        # Delete oldest logs, keeping 10 most recent
        find "$LOG_DIR" -name "run-*.log" -type f -print0 2>/dev/null \
            | xargs -0 ls -t \
            | tail -n +11 \
            | xargs rm -f 2>/dev/null || true
    fi
}

# ────────────────────────────────────────────────────────────────
# Sanitization
# ────────────────────────────────────────────────────────────────

sanitize_for_logging() {
    local message="$1"

    # Remove API keys (patterns like sk-*, ANTHROPIC_API_KEY=*, etc.)
    message=$(echo "$message" | sed -E 's/sk-[a-zA-Z0-9_-]{20,}/[API_KEY_REDACTED]/g')
    message=$(echo "$message" | sed -E 's/(API_KEY|TOKEN|PASSWORD|SECRET)[=:][^ ]*/\1=[REDACTED]/gi')

    # Sanitize home directory paths (replace with ~)
    message=$(echo "$message" | sed "s|$HOME|~|g")

    echo "$message"
}

# ────────────────────────────────────────────────────────────────
# Core Logging Functions
# ────────────────────────────────────────────────────────────────

log_message() {
    local level="$1"
    shift
    local message="$*"

    # Check if we should log this level
    local current_level_priority
    local message_level_priority
    current_level_priority=$(get_log_level_priority "$LOG_LEVEL")
    message_level_priority=$(get_log_level_priority "$level")

    if [ "$message_level_priority" -gt "$current_level_priority" ]; then
        return 0  # Skip logging this message
    fi

    # Sanitize message
    local sanitized_message
    sanitized_message="$(sanitize_for_logging "$message")"

    # Format log entry
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[$timestamp] [$level] $sanitized_message"

    # Write to log file if available
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi

    # Also output to stderr for ERROR and WARNING
    if [ "$level" = "ERROR" ] || [ "$level" = "WARNING" ]; then
        echo "$log_entry" >&2
    fi
}

log_info() {
    log_message "INFO" "$@"
}

log_warning() {
    log_message "WARNING" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

log_debug() {
    log_message "DEBUG" "$@"
}

# ────────────────────────────────────────────────────────────────
# Display Functions
# ────────────────────────────────────────────────────────────────

print_log_location() {
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Log file: $LOG_FILE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
}

view_log() {
    if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
        echo "ERROR: No log file available" >&2
        return 1
    fi

    # Display log file with optional filtering
    local filter_level="$1"

    if [ -n "$filter_level" ]; then
        grep "\[$filter_level\]" "$LOG_FILE" || echo "No $filter_level entries found"
    else
        cat "$LOG_FILE"
    fi
}

list_recent_logs() {
    if [ ! -d "$LOG_DIR" ]; then
        echo "No logs directory found" >&2
        return 1
    fi

    echo "Recent log files:"
    find "$LOG_DIR" -name "run-*.log" -type f -print0 2>/dev/null \
        | xargs -0 ls -t \
        | head -10 \
        | while read -r logfile; do
            local size
            size=$(du -h "$logfile" | cut -f1)
            local name
            name=$(basename "$logfile")
            echo "  $name ($size)"
        done
}

# ────────────────────────────────────────────────────────────────
# Cleanup on Exit
# ────────────────────────────────────────────────────────────────

finalize_logging() {
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        {
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "════════════════════════════════════════════════════════════════"
        } >> "$LOG_FILE"
    fi
}

# Export functions for use in other scripts
export -f init_logging
export -f rotate_logs
export -f sanitize_for_logging
export -f log_message
export -f log_info
export -f log_warning
export -f log_error
export -f log_debug
export -f print_log_location
export -f view_log
export -f list_recent_logs
export -f finalize_logging
