#!/usr/bin/env bash
set -Eeuo pipefail

UUID="Cinnamenu@json"
WALLPAPER_URL="https://raw.githubusercontent.com/Skatterbrainz/Garage/refs/heads/master/qYeaEQC-water-droplets-wallpaper.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER="$WALLPAPER_DIR/qYeaEQC-water-droplets-wallpaper.jpg"
APPLET_DIR="$HOME/.local/share/cinnamon/applets/$UUID"
BACKUP="$HOME/cinnamon-enabled-applets.backup"

command -v gsettings >/dev/null
command -v python3 >/dev/null
command -v curl >/dev/null
command -v unzip >/dev/null

# Back up current panel configuration.
gsettings get org.cinnamon enabled-applets > "$BACKUP"

# Install Cinnamenu if it isn't already installed.
if [[ ! -f "$APPLET_DIR/metadata.json" ]]; then
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
fi

# Download wallpaper.
mkdir -p "$WALLPAPER_DIR"
curl -fL --retry 2 "$WALLPAPER_URL" -o "$WALLPAPER"

# Configure panel: replace menu and center all existing applets.
# Preserve applet instance IDs and other suffix fields.
CURRENT="$(gsettings get org.cinnamon enabled-applets)"

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
gsettings set org.cinnamon enabled-applets "$UPDATED"
gsettings set org.cinnamon.desktop.background picture-uri \
    "file://$WALLPAPER"

# Also set the dark-mode wallpaper, where supported.
if gsettings list-keys org.cinnamon.desktop.background |
    grep -qx picture-uri-dark; then
    gsettings set org.cinnamon.desktop.background picture-uri-dark \
        "file://$WALLPAPER"
fi


#!/usr/bin/env bash
set -euo pipefail

SETTINGS="$HOME/.config/cinnamon/spices/Cinnamenu@json/0.json"

# Ensure Cinnamenu settings exist.
if [[ ! -f "$SETTINGS" ]]; then
    echo "Cinnamenu settings not found: $SETTINGS" >&2
    exit 1
fi

# Back up the current settings.
cp -a "$SETTINGS" "$SETTINGS.bak"

# Hide the caption and select the Cinnamon icon.
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

echo "Cinnamenu icon and caption configured."
echo "Restart Cinnamon or log out and back in to apply changes."

# Download ArtCraft App Launcher AppImage if not already present.
# Actual AppImage version may change, query for latest version
ARTCRAFT_URI="https://release-assets.githubusercontent.com/github-production-release-asset/1412548284/b396e42f-2e28-4b91-ac13-0da52bb43417?sp=r&sv=2018-11-09&sr=b&spr=https&se=2026-10-20T22%3A15%3A43Z&rscd=attachment%3B+filename%3Dartcraft-launcher-0.5.1-linux-x86_64.AppImage&rsct=application%2Foctet-stream&skoid=96c2d410-5711-43a1-aedd-ab1947aa7ab0&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skt=2026-10-20T21%3A15%3A18Z&ske=2026-10-20T22%3A15%3A43Z&sks=b&skv=2018-11-09&sig=NeeK%2F8TfffspDpnhWcmG2UDfEKW2tB2il14qKdM3o2k%3D&jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmVsZWFzZS1hc3NldHMuZ2l0aHVidXNlcmNvbnRlbnQuY29tIiwia2V5Ijoia2V5MSIsImV4cCI6MTc5MjUzMzI1MywibmJmIjoxNzkyNTMxNDUzLCJwYXRoIjoicmVsZWFzZWFzc2V0cHJvZHVjdGlvbi5ibG9iLmNvcmUud2luZG93cy5uZXQifQ.D3tcvVFO7J56nLNRx1JSus0KtSacr948vR876qbrLgg&response-content-disposition=attachment%3B%20filename%3Dartcraft-launcher-0.5.1-linux-x86_64.AppImage&response-content-type=application%2Foctet-stream"
ARTCRAFT_APPIMAGE="$HOME/AppImages/artcraft-launcher-0.5.1-linux-x86_64.AppImage"
mkdir -p "$HOME/AppImages"
if [[ ! -f "$ARTCRAFT_APPIMAGE" ]]; then
    wget -O "$ARTCRAFT_APPIMAGE" "$ARTCRAFT_URI"
    chmod +x "$ARTCRAFT_APPIMAGE"
fi
echo "Configuration applied."
echo "Wallpaper: $WALLPAPER"
echo "Panel backup: $BACKUP"
echo "Log out and back in if Cinnamon does not reload the applet."
