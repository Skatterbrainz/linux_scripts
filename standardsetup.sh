#!/usr/bin/env bash
set -Eeuo pipefail

UUID="Cinnamenu@json"
WALLPAPER_URL="https://raw.githubusercontent.com/Skatterbrainz/Garage/refs/heads/master/qYeaEQC-water-droplets-wallpaper.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER="$WALLPAPER_DIR/qYeaEQC-water-droplets-wallpaper.jpg"
APPLET_DIR="$HOME/.local/share/cinnamon/applets/$UUID"
ARTCRAFT_URI="https://github.com/storytold/craft-launcher/releases/download/v0.6.1/artcraft-launcher-0.6.1-linux-x86_64.AppImage"
ARTCRAFT_PATH="$HOME/AppImages/$(basename "$ARTCRAFT_URI")"
BACKUP="$HOME/cinnamon-enabled-applets.backup"
SCRIPT_PATH="${BASH_SOURCE[0]-}"
DEFAULT_TOTAL_STEPS=9
TOTAL_STEPS="$DEFAULT_TOTAL_STEPS"
CURRENT_STEP=0

status() {
    echo "[standard.sh] $*"
}

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo "[standard.sh] [${CURRENT_STEP}/${TOTAL_STEPS}] $*"
}

if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
    DETECTED_STEPS="$(grep -Ec '^[[:space:]]*step "' "$SCRIPT_PATH" || true)"
    if [[ "$DETECTED_STEPS" -gt 0 ]]; then
        TOTAL_STEPS="$DETECTED_STEPS"
    fi
fi

step "Starting Cinnamon desktop setup..."
step "Checking required commands..."
command -v gsettings >/dev/null
command -v python3 >/dev/null
command -v curl >/dev/null
command -v unzip >/dev/null
status "Dependencies look good."

# Back up current panel configuration.
step "Backing up current panel configuration to $BACKUP"
gsettings get org.cinnamon enabled-applets > "$BACKUP"

# Install Cinnamenu if it isn't already installed.
step "Ensuring Cinnamenu is installed..."
if [[ ! -f "$APPLET_DIR/metadata.json" ]]; then
    status "Cinnamenu not found locally. Downloading and installing..."
    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT

    curl -fL --retry 2 \
        "https://cinnamon-spices.linuxmint.com/files/applets/${UUID}.zip" \
        -o "$TMPDIR/applet.zip"

    mkdir -p "$HOME/.local/share/cinnamon/applets"
    unzip -q "$TMPDIR/applet.zip" -d "$TMPDIR/unpacked"

    SOURCE="$(find "$TMPDIR/unpacked" -type f \
        -name metadata.json -print -quit)"

    if [[ -z "$SOURCE" ]]; then
        echo "Could not find Cinnamenu metadata.json in downloaded archive." >&2
        exit 1
    fi

    mkdir -p "$APPLET_DIR"
    cp -a "$(dirname "$SOURCE")/." "$APPLET_DIR/"
    status "Cinnamenu installed to $APPLET_DIR"
else
    status "Cinnamenu already installed. Skipping applet download."
fi

# Download wallpaper.
step "Downloading wallpaper to $WALLPAPER"
mkdir -p "$WALLPAPER_DIR"
curl -fL --retry 2 "$WALLPAPER_URL" -o "$WALLPAPER"
status "Wallpaper downloaded."

# Configure panel: replace menu and center all existing applets.
# Preserve applet instance IDs and other suffix fields.
step "Updating panel applets and wallpaper settings..."
status "Reading current panel applets..."
CURRENT="$(gsettings get org.cinnamon enabled-applets)"

status "Preparing updated panel applet layout..."
UPDATED="$(python3 - "$CURRENT" <<'PY'
import ast
import sys

items = ast.literal_eval(sys.argv[1])
result = []
seen_menu = False

for item in items:
    fields = item.split(":")
    if len(fields) < 4:
        raise SystemExit(f"Unexpected applet entry: {item}")

    panel, zone, position, uuid = fields[:4]
    suffix = fields[4:]

    if uuid == "menu@cinnamon.org":
        if seen_menu:
            continue
        uuid = "Cinnamenu@json"
        seen_menu = True
    elif uuid == "Cinnamenu@json":
        if seen_menu:
            continue
        seen_menu = True

    # Center all applets on their existing panel.
    fields = [panel, "center", str(len([
        x for x in result if x.split(":")[0] == panel
    ])), uuid, *suffix]
    result.append(":".join(fields))

if not seen_menu:
    raise SystemExit("No default menu or Cinnamenu entry found; panel unchanged.")

print(repr(result))
PY
)"

# Apply settings only after preparation succeeds.
status "Applying centered panel layout and wallpaper settings..."
gsettings set org.cinnamon enabled-applets "$UPDATED"
gsettings set org.cinnamon.desktop.background picture-uri \
    "file://$WALLPAPER"

# Also set the dark-mode wallpaper, where supported.
if gsettings list-keys org.cinnamon.desktop.background |
    grep -qx picture-uri-dark; then
    status "Applying dark-mode wallpaper setting..."
    gsettings set org.cinnamon.desktop.background picture-uri-dark \
        "file://$WALLPAPER"
fi

SPICES_DIR="$HOME/.config/cinnamon/spices/$UUID"

# Resolve the active Cinnamenu instance settings file.
step "Configuring Cinnamenu icon/caption settings..."
status "Resolving Cinnamenu settings file..."
INSTANCE_ID="$(python3 - "$(gsettings get org.cinnamon enabled-applets)" "$UUID" <<'PY'
import ast
import sys

items = ast.literal_eval(sys.argv[1])
uuid = sys.argv[2]

for item in items:
    fields = item.split(":")
    if len(fields) >= 5 and fields[3] == uuid:
        print(fields[4])
        break
PY
)"

SETTINGS=""
if [[ -n "$INSTANCE_ID" && -f "$SPICES_DIR/$INSTANCE_ID.json" ]]; then
    SETTINGS="$SPICES_DIR/$INSTANCE_ID.json"
elif [[ -d "$SPICES_DIR" ]]; then
    SETTINGS="$(find "$SPICES_DIR" -maxdepth 1 -type f -name '*.json' -print -quit)"
fi

if [[ -n "$SETTINGS" ]]; then
    # Back up the current settings.
    status "Backing up Cinnamenu settings to $SETTINGS.bak"
    cp -a "$SETTINGS" "$SETTINGS.bak"

    # Hide the caption and select the Cinnamon icon.
    status "Updating Cinnamenu icon and caption settings..."
    python3 - "$SETTINGS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

with path.open(encoding="utf-8") as f:
    settings = json.load(f)

def set_setting(key, value):
    if key not in settings:
        return False
    entry = settings[key]
    if isinstance(entry, dict) and "value" in entry:
        entry["value"] = value
    else:
        settings[key] = value
    return True

def get_setting(key):
    value = settings.get(key)
    if isinstance(value, dict) and "value" in value:
        return value["value"]
    return value

set_setting("menu-label", "")
set_setting("menu-icon-custom", True)
set_setting("menu-icon", "cinnamon-symbolic")

with path.open("w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
    f.write("\n")

print(
    "Applied values: "
    f"menu-label={get_setting('menu-label')!r}, "
    f"menu-icon-custom={get_setting('menu-icon-custom')!r}, "
    f"menu-icon={get_setting('menu-icon')!r}"
)
PY

    status "Configured values: $(python3 - "$SETTINGS" <<'PY'
import json
import sys
from pathlib import Path

settings = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

def get_setting(key):
    value = settings.get(key)
    if isinstance(value, dict) and "value" in value:
        return value["value"]
    return value

print(
    f"menu-label={get_setting('menu-label')!r}, "
    f"menu-icon-custom={get_setting('menu-icon-custom')!r}, "
    f"menu-icon={get_setting('menu-icon')!r}"
)
PY
)"
    status "Cinnamenu icon and caption configured: $SETTINGS"
else
    echo "Cinnamenu settings file not found under: $SPICES_DIR" >&2
    echo "Skipping icon/caption customization for now; continue to next tasks." >&2
fi

# Download ArtCraft App Launcher AppImage if not already present.
step "Ensuring ArtCraft AppImage is available..."
status "Resolving latest ArtCraft AppImage URL from GitHub releases..."
#ARTCRAFT_URI=""
#ARTCRAFT_NAME=""
for repo in \
    "storytold/craft-launcher" \
    "storytold/artcraft" \
    "Skatterbrainz/artcraft-launcher" \
    "EricVogt93/artcraft-launcher"; do
    status "Checking ${repo} releases page..."
    LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        -H "User-Agent: linux_scripts-standard" \
        "https://github.com/${repo}/releases/latest" 2>/dev/null || true)"
    if [[ -z "$LATEST_URL" || "$LATEST_URL" != *"/releases/tag/"* ]]; then
        continue
    fi

    RELEASE_TAG="${LATEST_URL##*/}"
    RELEASE_HTML="$(curl -fsSL \
        -H "User-Agent: linux_scripts-standard" \
        "https://github.com/${repo}/releases/expanded_assets/${RELEASE_TAG}" \
        2>/dev/null || true)"
    if [[ -z "$RELEASE_HTML" ]]; then
        continue
    fi

    ARTCRAFT_RELEASE_INFO=()
    if readarray -t ARTCRAFT_RELEASE_INFO < <(python3 - <<'PY' <<<"$RELEASE_HTML"
import re
import sys
from urllib.parse import unquote

html = sys.stdin.read()
matches = re.findall(
    r'href="([^"]*/releases/download/[^"]*\.AppImage)"',
    html,
    flags=re.IGNORECASE,
)

if not matches:
    sys.exit(1)

def normalize(url):
    if url.startswith("/"):
        return f"https://github.com{url}"
    return url

def rank(name):
    lowered = name.lower()
    if "x86_64" in lowered or "amd64" in lowered:
        return 0
    if "linux" in lowered:
        return 1
    return 2

choices = []
for href in matches:
    url = normalize(href)
    name = unquote(url.rsplit("/", 1)[-1])
    choices.append((rank(name), name, url))

choices.sort()
best = choices[0]
print(best[1])
print(best[2])
PY
    ); then
        ARTCRAFT_NAME="${ARTCRAFT_RELEASE_INFO[0]-}"
        ARTCRAFT_URI="${ARTCRAFT_RELEASE_INFO[1]-}"
        status "Using ArtCraft release from ${repo}: ${ARTCRAFT_NAME}"
        break
    fi
done

if [[ -n "$ARTCRAFT_URI" && -n "$ARTCRAFT_NAME" ]]; then
    ARTCRAFT_APPIMAGE="$HOME/AppImages/$ARTCRAFT_NAME"
    mkdir -p "$HOME/AppImages"
    if [[ ! -f "$ARTCRAFT_APPIMAGE" ]]; then
        status "Downloading ArtCraft AppImage to $ARTCRAFT_APPIMAGE"
        curl -fL --retry 2 -H "User-Agent: linux_scripts-standard" \
            -o "$ARTCRAFT_APPIMAGE" "$ARTCRAFT_URI"
        chmod +x "$ARTCRAFT_APPIMAGE"
        status "ArtCraft AppImage downloaded and marked executable."
    else
        status "ArtCraft AppImage already exists. Skipping download."
    fi
else
    echo "Could not find an AppImage asset in known ArtCraft release pages." >&2
    echo "Skipping ArtCraft download and continuing setup." >&2
fi

step "Reloading Cinnamon desktop shell (optional)..."
VIRT_ENV="unknown"
if command -v systemd-detect-virt >/dev/null; then
    VIRT_ENV="$(systemd-detect-virt 2>/dev/null || echo unknown)"
fi

if [[ "${AUTO_RELOAD_CINNAMON:-0}" != "1" ]]; then
    status "Automatic Cinnamon reload is disabled by default for safety."
    status "Run 'cinnamon -r' manually when ready (or set AUTO_RELOAD_CINNAMON=1)."
elif [[ "$VIRT_ENV" != "none" && "$VIRT_ENV" != "unknown" ]]; then
    echo "Detected virtualized environment (${VIRT_ENV}); skipping automatic Cinnamon reload." >&2
    echo "Run 'cinnamon -r' manually only when safe in your VM session." >&2
elif ! command -v cinnamon >/dev/null; then
    echo "Cinnamon executable not found; skipping automatic shell reload." >&2
elif ! command -v timeout >/dev/null; then
    echo "timeout command not found; skipping automatic Cinnamon reload to avoid hangs." >&2
    echo "Run 'cinnamon -r' manually from your desktop session." >&2
else
    status "Attempting automatic Cinnamon reload with timeout..."
    if timeout 10s cinnamon -r; then
        status "Cinnamon desktop shell reloaded successfully."
    else
        reload_exit="$?"
        if [[ "$reload_exit" -eq 124 ]]; then
            echo "Automatic Cinnamon reload timed out; skipping to avoid desktop lockup." >&2
        else
            echo "Could not reload Cinnamon automatically with 'cinnamon -r' (exit ${reload_exit})." >&2
        fi
        echo "Please run 'cinnamon -r' manually from your desktop session if needed." >&2
    fi
fi

step "Configuration applied successfully."
status "Wallpaper: $WALLPAPER"
status "Panel backup: $BACKUP"
status "Log out and back in if Cinnamon does not reload the applet."
