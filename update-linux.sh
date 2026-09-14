#!/usr/bin/env bash
#
# update-system.sh
# Detects available package managers on a Linux system and either shows
# pending updates (dry run, default) or actually applies them (--apply).
#
# Usage:
#   ./update-system.sh                # DRY RUN (default) — lists pending updates, changes nothing
#   sudo ./update-system.sh --apply   # actually runs the updates
#
# Notes:
#   - Dry run is the default and safe to run as any user; it refreshes
#     package indexes (read-only) and lists what's upgradable per-package.
#   - Pass --apply (or -y) to perform real updates. Run with sudo at that
#     point for full coverage — apt/dnf/yum/zypper/pacman need root;
#     flatpak/snap generally don't (snap refresh may need sudo depending
#     on distro config).

set -uo pipefail

DRY_RUN=true
case "${1:-}" in
    "")
        ;;
    --apply|-y)
        DRY_RUN=false
        ;;
    --dry-run|-n)
        DRY_RUN=true
        ;;
    -h|--help)
        echo "Usage: $0 [--apply|-y]"
        echo "  (no argument)   Dry run — list pending updates, change nothing (default)"
        echo "  --apply, -y     Actually run the updates"
        echo "  --dry-run, -n   Explicitly request a dry run (same as no argument)"
        exit 0
        ;;
    *)
        echo "Error: unrecognized argument '$1'" >&2
        echo "Usage: $0 [--apply|-y]" >&2
        exit 1
        ;;
esac

if $DRY_RUN; then
    echo "Dry run mode (default) — listing pending updates only, no changes will be made."
    echo "Pass --apply to actually run updates."
fi

log() {
    printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

require_root_hint() {
    if [[ $EUID -ne 0 ]] && ! $DRY_RUN; then
        echo "Note: not running as root — this step may prompt for sudo or fail." >&2
    fi
}

UPDATED_ANYTHING=false

# --- APT (Debian/Ubuntu) ---
if command -v apt-get &>/dev/null; then
    log "APT detected"
    require_root_hint
    sudo apt-get update -qq
    if $DRY_RUN; then
        echo "Packages that would be upgraded:"
        apt list --upgradable 2>/dev/null | tail -n +2
    else
        sudo apt-get upgrade -y
        sudo apt-get autoremove -y
    fi
    UPDATED_ANYTHING=true
fi

# --- DNF (Fedora / modern RHEL) ---
if command -v dnf &>/dev/null; then
    log "DNF detected"
    require_root_hint
    if $DRY_RUN; then
        echo "Packages that would be upgraded:"
        sudo dnf check-update || true   # exit code 100 means updates are available; not an error
    else
        sudo dnf upgrade --refresh -y
    fi
    UPDATED_ANYTHING=true

# --- YUM (older RHEL/CentOS) — only if dnf isn't already handling it ---
elif command -v yum &>/dev/null; then
    log "YUM detected"
    require_root_hint
    if $DRY_RUN; then
        echo "Packages that would be upgraded:"
        sudo yum check-update || true   # exit code 100 means updates are available; not an error
    else
        sudo yum update -y
    fi
    UPDATED_ANYTHING=true
fi

# --- Zypper (openSUSE) ---
if command -v zypper &>/dev/null; then
    log "Zypper detected"
    require_root_hint
    sudo zypper refresh
    if $DRY_RUN; then
        echo "Packages that would be upgraded:"
        zypper list-updates
    else
        sudo zypper update -y
    fi
    UPDATED_ANYTHING=true
fi

# --- Pacman (Arch/Manjaro) ---
if command -v pacman &>/dev/null; then
    log "Pacman detected"
    require_root_hint
    if $DRY_RUN; then
        echo "Packages that would be upgraded:"
        if command -v checkupdates &>/dev/null; then
            checkupdates
        else
            echo "(install 'pacman-contrib' for a safe, non-syncing 'checkupdates' preview;"
            echo " falling back to 'pacman -Qu', which only reflects the last synced database)"
            pacman -Qu || echo "No updates found in the local package database."
        fi
    else
        sudo pacman -Syu --noconfirm
    fi
    UPDATED_ANYTHING=true
fi

# --- Flatpak ---
if command -v flatpak &>/dev/null; then
    log "Flatpak detected"
    if $DRY_RUN; then
        echo "Flatpak apps/runtimes that would be updated:"
        flatpak remote-ls --updates
    else
        flatpak update -y
    fi
    UPDATED_ANYTHING=true
fi

# --- Snap ---
if command -v snap &>/dev/null; then
    log "Snap detected"
    if $DRY_RUN; then
        echo "Snaps that would be refreshed:"
        snap refresh --list
    else
        sudo snap refresh
    fi
    UPDATED_ANYTHING=true
fi

# --- Flag if nothing was found ---
if ! $UPDATED_ANYTHING; then
    echo "No supported package managers (apt, dnf, yum, zypper, pacman, flatpak, snap) were found."
    exit 1
fi

if $DRY_RUN; then
    log "Dry run complete. Re-run with --apply to install the above."
else
    log "Done."
fi
