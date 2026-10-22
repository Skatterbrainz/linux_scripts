#!/usr/bin/env bash
set -Eeuo pipefail

UUID="Cinnamenu@json"
WALLPAPER_URL="https://raw.githubusercontent.com/Skatterbrainz/Garage/refs/heads/master/qYeaEQC-water-droplets-wallpaper.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER="$WALLPAPER_DIR/qYeaEQC-water-droplets-wallpaper.jpg"
APPLET_DIR="$HOME/.local/share/cinnamon/applets/$UUID"
BACKUP="$HOME/cinnamon-enabled-applets.backup"
SCRIPT_PATH="${BASH_SOURCE[0]}"
TOTAL_STEPS=0
CURRENT_STEP=0

status() {
    echo "[standard.sh] $*"
}

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo "[standard.sh] [${CURRENT_STEP}/${TOTAL_STEPS}] $*"
}

TOTAL_STEPS="$(grep -Ec '^[[:space:]]*step "' "$SCRIPT_PATH" || true)"
if [[ "$TOTAL_STEPS" -le 0 ]]; then
    TOTAL_STEPS=1
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

settings["menu-label"]["value"] = ""
settings["menu-icon-custom"]["value"] = True
settings["menu-icon"]["value"] = "cinnamon"

with path.open("w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
    f.write("\n")
PY

    status "Cinnamenu icon and caption configured: $SETTINGS"
else
    echo "Cinnamenu settings file not found under: $SPICES_DIR" >&2
    echo "Skipping icon/caption customization for now; continue to next tasks." >&2
fi

# Download ArtCraft App Launcher AppImage if not already present.
step "Ensuring ArtCraft AppImage is available..."
status "Querying latest ArtCraft release metadata..."
readarray -t ARTCRAFT_RELEASE_INFO < <(
    curl -fsSL \
        "https://api.github.com/repos/Skatterbrainz/artcraft-launcher/releases/latest" \
        | python3 - <<'PY'
import json
import sys

release = json.load(sys.stdin)
for asset in release.get("assets", []):
    name = asset.get("name", "")
    if name.endswith("-linux-x86_64.AppImage"):
        print(name)
        print(asset.get("browser_download_url", ""))
        break
else:
    raise SystemExit("No linux x86_64 AppImage asset found in latest release.")
PY
)

if [[ "${#ARTCRAFT_RELEASE_INFO[@]}" -ne 2 ||
      -z "${ARTCRAFT_RELEASE_INFO[0]}" ||
      -z "${ARTCRAFT_RELEASE_INFO[1]}" ]]; then
    echo "Could not determine latest ArtCraft AppImage download URL." >&2
    exit 1
fi

ARTCRAFT_APPIMAGE="$HOME/AppImages/${ARTCRAFT_RELEASE_INFO[0]}"
ARTCRAFT_URI="${ARTCRAFT_RELEASE_INFO[1]}"
mkdir -p "$HOME/AppImages"
if [[ ! -f "$ARTCRAFT_APPIMAGE" ]]; then
    status "Downloading ArtCraft AppImage to $ARTCRAFT_APPIMAGE"
    curl -fL --retry 2 -o "$ARTCRAFT_APPIMAGE" "$ARTCRAFT_URI"
    chmod +x "$ARTCRAFT_APPIMAGE"
    status "ArtCraft AppImage downloaded and marked executable."
else
    status "ArtCraft AppImage already exists. Skipping download."
fi

step "Configuration applied successfully."
status "Wallpaper: $WALLPAPER"
status "Panel backup: $BACKUP"
status "Log out and back in if Cinnamon does not reload the applet."
