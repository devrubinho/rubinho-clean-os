#!/usr/bin/env bash

#
# Platform Detection Module
#
# Automatically detects the operating system (Linux or macOS) and exports
# platform identifiers and helper functions for use throughout the codebase.
#
# Usage:
#   source lib/platform.sh
#   if is_macos; then
#     echo "Running on macOS"
#   fi
#

# Exit on error (can be overridden by sourcing scripts)
set -eo pipefail

# Detect platform using uname
detect_platform() {
    local os_type
    os_type="$(uname -s)"

    case "$os_type" in
        Linux*)
            # Check if running under WSL (Windows Subsystem for Linux)
            if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
                export PLATFORM="linux"
                export PLATFORM_NAME="Linux (WSL)"
                export IS_WSL="true"
            else
                export PLATFORM="linux"
                export PLATFORM_NAME="Linux"
                export IS_WSL="false"
            fi

            # Detect Linux distribution
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                export LINUX_DISTRO="${ID:-unknown}"
                export LINUX_DISTRO_VERSION="${VERSION_ID:-unknown}"
            else
                export LINUX_DISTRO="unknown"
                export LINUX_DISTRO_VERSION="unknown"
            fi

            # Set package manager
            if command -v apt-get &> /dev/null; then
                export PKG_MANAGER="apt-get"
                export PKG_INSTALL_CMD="apt-get install -y"
                export PKG_UPDATE_CMD="apt-get update"
            elif command -v dnf &> /dev/null; then
                export PKG_MANAGER="dnf"
                export PKG_INSTALL_CMD="dnf install -y"
                export PKG_UPDATE_CMD="dnf check-update"
            elif command -v yum &> /dev/null; then
                export PKG_MANAGER="yum"
                export PKG_INSTALL_CMD="yum install -y"
                export PKG_UPDATE_CMD="yum check-update"
            else
                export PKG_MANAGER="unknown"
                export PKG_INSTALL_CMD=""
                export PKG_UPDATE_CMD=""
            fi
            ;;

        Darwin*)
            export PLATFORM="macos"
            export PLATFORM_NAME="macOS"
            export IS_WSL="false"

            # Detect macOS version
            if command -v sw_vers &> /dev/null; then
                export MACOS_VERSION="$(sw_vers -productVersion)"
            else
                export MACOS_VERSION="unknown"
            fi

            # Set package manager (Homebrew)
            if command -v brew &> /dev/null; then
                export PKG_MANAGER="brew"
                export PKG_INSTALL_CMD="brew install"
                export PKG_UPDATE_CMD="brew update"
            else
                export PKG_MANAGER="unknown"
                export PKG_INSTALL_CMD=""
                export PKG_UPDATE_CMD=""
            fi
            ;;

        *)
            echo "ERROR: Unsupported platform detected: $os_type" >&2
            echo "This script only supports Linux and macOS." >&2
            echo "Detected OS type: $os_type" >&2
            return 1
            ;;
    esac

    return 0
}

# Helper function to check if running on Linux
is_linux() {
    [ "$PLATFORM" = "linux" ]
}

# Helper function to check if running on macOS
is_macos() {
    [ "$PLATFORM" = "macos" ]
}

# Helper function to check if running under WSL
is_wsl() {
    [ "$IS_WSL" = "true" ]
}

# Helper function to check if package manager is available
has_package_manager() {
    [ "$PKG_MANAGER" != "unknown" ] && [ -n "$PKG_MANAGER" ]
}

# Helper function to print platform information
print_platform_info() {
    echo "Platform: $PLATFORM_NAME"

    if is_linux; then
        echo "Distribution: $LINUX_DISTRO $LINUX_DISTRO_VERSION"
        if is_wsl; then
            echo "Environment: WSL (Windows Subsystem for Linux)"
        fi
    elif is_macos; then
        echo "macOS Version: $MACOS_VERSION"
    fi

    if has_package_manager; then
        echo "Package Manager: $PKG_MANAGER"
    else
        echo "Package Manager: Not detected"
    fi
}

# Run detection on source
if ! detect_platform; then
    # If detection fails, exit with error
    return 1 2>/dev/null || exit 1
fi

# Export functions for use in other scripts
export -f is_linux
export -f is_macos
export -f is_wsl
export -f has_package_manager
export -f print_platform_info
