#!/bin/bash
#-------------------------------------------------------------
# Linux Mint setup script by Skatterbrainz
# version: 1.19.0, 10/24/2026
#-------------------------------------------------------------
# To invoke this from a terminal using wget or curl obtain the URL from the "raw" view of this script:
# wget -O /tmp/mint_setup.sh <URL> && /tmp/mint_setup.sh
# or
# curl -fsL <URL> | bash
#-------------------------------------------------------------
INSTALL_BRAVE=true
INSTALL_VSCODE=true
INSTALL_POWERSHELL=true
INSTALL_VIRTUALBOX=true
INSTALL_APPLET_VBOX=true
INSTALL_EXTENSION_VBOX=true
INSTALL_ARTCRAFT=true
ENABLE_FIREWALL=true
INSTALL_APPLETS=true
INSTALL_EXTENSIONS=true
INSTALL_WALLPAPER=true
CONFIGURE_PANEL=true
CONFIGURE_NEMO=true
# Cinnamenu icon can be a theme icon name ("cinnamon-symbolic") or an absolute image path.
CINNAMENU_ICON="cinnamon-symbolic"
# Calendar applet: enable "Use a custom date format".
CALENDAR_USE_CUSTOM_FORMAT=true
CALENDAR_CUSTOM_FORMAT="%A, %B %e, %H:%M"
CALENDAR_CUSTOM_TOOLTIP_FORMAT="%A, %B %e, %H:%M"
# Ordered launcher IDs to pin first in the Grouped Window List (center panel).
declare -a GROUPED_WINDOW_PINNED_LAUNCHERS=(
	"libreoffice-writer.desktop"                          # LibreOffice Writer
	"libreoffice-calc.desktop"                            # LibreOffice Calc
	"libreoffice-impress.desktop"                         # LibreOffice Impress
	"drawio.desktop"                                      # Draw.io (falls back to common alt IDs)
	"code.desktop"                                        # Visual Studio Code
	"brave-browser.desktop"                               # Brave Browser
	"shutter"                                             # Shutter
	"com.github.IsmaelMartinez.teams_for_linux.desktop:flatpak" # Teams for Linux
	"md.obsidian.Obsidian"                                # Obsidian
	"com.getpostman.Postman"                              # Postman
	"io.github.shiftey.Desktop"                           # GitHub Desktop
)

declare -a aptpackages=(
	"git"
	"gh"
	"adwaita-icon-theme"
	"glogg"
	"kcolorchooser"
	"kpat"
	"nala"
	"shutter"
	"yad"
	"yt-dlp"
	"cargo"
	"puddletag"
	"jq"
	"smartmontools"
	"gsmartcontrol"
)

declare -a flatpak_apps=(
	"com.bitwarden.desktop"
	"org.gimp.GIMP"
	"org.gtk.Gtk3theme.Adapta-Nokto"
	"org.gnome.Papers"
	"org.gtk.Gtk3theme.Mint-Y-Dark"
	"org.gtk.Gtk3theme.Mint-Y-Dark-Blue"
	"org.localsend.localsend_app"
	"org.qbittorrent.qBittorrent"
	"org.nickvision.tubeconverter"
	"com.github.IsmaelMartinez.teams_for_linux"
	"org.kde.kdenlive"
	"org.kde.kleopatra"
	"md.obsidian.Obsidian"
	"com.github.wwmm.easyeffects"
	"com.getpostman.Postman"
	"io.github.shiftey.Desktop"
)

WALLPAPER_URL="https://raw.githubusercontent.com/Skatterbrainz/Garage/refs/heads/master/qYeaEQC-water-droplets-wallpaper.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER="$WALLPAPER_DIR/qYeaEQC-water-droplets-wallpaper.jpg"
ARTCRAFT_URI="https://github.com/storytold/craft-launcher/releases/download/v0.7.0/artcraft-launcher-0.7.0-linux-x86_64.AppImage"
ARTCRAFT_PATH="$HOME/Applications/$(basename "$ARTCRAFT_URI")"
ARTCRAFT_ONCE_SCRIPT="$HOME/.local/bin/mintsetup-launch-artcraft-once.sh"
ARTCRAFT_ONCE_DESKTOP="$HOME/.config/autostart/mintsetup-artcraft-once.desktop"
ARTCRAFT_ONCE_DONE_MARKER="$HOME/.local/state/mintsetup/artcraft-once-launch.done"
mkdir -p "$HOME/Applications"

LOG_FILE="$HOME/mintsetup.log"
LOG_FILE_PREVIOUS="$HOME/mintsetup.log.1"
if [ -f "$LOG_FILE" ]; then
	mv -f "$LOG_FILE" "$LOG_FILE_PREVIOUS"
fi
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[INFO] ===== mint_setup.sh started at $(date '+%Y-%m-%d %H:%M:%S') ====="

#-------------------------------------------------------------
# Color codes and logging functions
#-------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

#-------------------------------------------------------------
# Logging functions for different message levels
#-------------------------------------------------------------

log() {
	echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
	echo -e "${CYAN}[INFO]${NC} $1"
}

warn() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1"
	exit 1
}

trap 'script_exit_code=$?; echo "[INFO] ===== mint_setup.sh finished at $(date "+%Y-%m-%d %H:%M:%S") (exit code: ${script_exit_code}) ====="' EXIT

repair_ubuntu_mirrors() {
	info "*** Falling back to official Ubuntu mirrors..."
	local source_file
	local source_files=("/etc/apt/sources.list")

	if compgen -G "/etc/apt/sources.list.d/*.list" > /dev/null; then
		for source_file in /etc/apt/sources.list.d/*.list; do
			source_files+=("$source_file")
		done
	fi

	if compgen -G "/etc/apt/sources.list.d/*.sources" > /dev/null; then
		for source_file in /etc/apt/sources.list.d/*.sources; do
			source_files+=("$source_file")
		done
	fi

	for source_file in "${source_files[@]}"; do
		[ -f "$source_file" ] || continue
		sudo sed -i -E \
			's|https?://[^/[:space:]]+/ubuntu|http://archive.ubuntu.com/ubuntu|g' \
			"$source_file"
	done
}

safe_apt_update() {
	local apt_log
	apt_log="$(mktemp)"

	if sudo DEBIAN_FRONTEND=noninteractive apt update < /dev/null > >(tee "$apt_log") 2>&1; then
		rm -f "$apt_log"
		return 0
	fi

	warn "*** apt update failed. Attempting mirror recovery..."
	info "*** Mirrors reported by apt before recovery:"
	while IFS= read -r mirror_host; do
		[ -z "$mirror_host" ] && continue
		info "*** Mirror host: $mirror_host"
		grep -Rns --no-messages \
			"$mirror_host" \
			/etc/apt/sources.list \
			/etc/apt/sources.list.d \
			|| warn "*** No apt source entry found for: $mirror_host"
	done < <(
		grep -E '^(Err:|E: Failed to fetch )https?://' "$apt_log" |
		sed -E 's|.*https?://([^/[:space:]]+).*|\1|' |
		sort -u
	)

	repair_ubuntu_mirrors
	sudo apt clean
	sudo rm -rf /var/lib/apt/lists/*
	rm -f "$apt_log"
	sudo DEBIAN_FRONTEND=noninteractive apt update < /dev/null || error "apt update failed after mirror recovery"
}

dedupe_nala_sources() {
	local nala_sources_file="/etc/apt/sources.list.d/nala-sources.list"
	local tmp_file

	[ -f "$nala_sources_file" ] || return 0
	tmp_file="$(mktemp)"

	sudo awk '!seen[$0]++' "$nala_sources_file" > "$tmp_file"
	sudo mv "$tmp_file" "$nala_sources_file"
}

#-------------------------------------------------------------
# Check if running as root
#-------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
fi

# Check if running on Linux Mint
if ! grep -q "Linux Mint" /etc/os-release; then
	warn "This script was designed for Linux Mint but will attempt to run anyway"
fi

log "Starting system setup..."

VIRTUAL_GUEST_TYPE="none"
detect_virtual_guest() {
	local detected=""

	if command -v systemd-detect-virt >/dev/null 2>&1; then
		detected="$(systemd-detect-virt 2>/dev/null || true)"
		if systemd-detect-virt --vm --quiet 2>/dev/null; then
			VIRTUAL_GUEST_TYPE="$detected"
			return 0
		fi
	fi

	for dmi_file in \
		"/sys/class/dmi/id/product_name" \
		"/sys/class/dmi/id/product_version" \
		"/sys/class/dmi/id/sys_vendor" \
		"/sys/class/dmi/id/board_vendor"; do
		if [ -r "$dmi_file" ] && grep -Eqi 'virtualbox|innotek|oracle vm|vmware|kvm|qemu|xen|hyper-v|microsoft corporation|parallels|bhyve|bochs|rhev' "$dmi_file"; then
			VIRTUAL_GUEST_TYPE="dmi"
			return 0
		fi
	done

	return 1
}

if detect_virtual_guest; then
	if [ "$INSTALL_VIRTUALBOX" = true ]; then
		warn "*** Virtual machine guest detected ($VIRTUAL_GUEST_TYPE); disabling VirtualBox host install and dependent integrations"
	fi
	INSTALL_VIRTUALBOX=false
	INSTALL_APPLET_VBOX=false
	INSTALL_EXTENSION_VBOX=false
fi

VIRTUALBOX_AVAILABLE=false

safe_apt_update

FILE="/usr/bin/nala"
if [ -f "$FILE" ]; then
	log "*** Nala is already installed"
else
	info "*** Installing Nala..."
	sudo DEBIAN_FRONTEND=noninteractive apt install -y nala < /dev/null
	info "*** Updating Nala repository list..."
	sudo nala fetch --auto --fetches 8 --country US < /dev/null
	safe_apt_update
	log "*** Nala installed successfully"
fi

dedupe_nala_sources
safe_apt_update

#-------------------------------------------------------------
## Apt packages 
#-------------------------------------------------------------

info "*** Installing apt package set..."
sudo nala install -y "${aptpackages[@]}" < /dev/null

#-------------------------------------------------------------
## Brave Browser
#-------------------------------------------------------------

if [ "$INSTALL_BRAVE" = true ]; then
	FILE="/usr/bin/brave-browser"
	if [ -f "$FILE" ]; then
		log "*** Brave Browser is already installed"
	else
		info "*** Installing Brave Browser..."
		sudo DEBIAN_FRONTEND=noninteractive apt install curl ca-certificates -y < /dev/null
		sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
		sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
		safe_apt_update
		sudo apt install brave-browser -y < /dev/null
		#curl -fsS https://dl.brave.com/install.sh | bash
	fi
fi

cd ~/Downloads

#-------------------------------------------------------------
## PowerShell 7.6.8 (may need to update often)
#-------------------------------------------------------------

if [ "$INSTALL_POWERSHELL" = true ]; then
	FILE="/opt/microsoft/powershell/7/pwsh"
	if [ -f "$FILE" ]; then
		log "*** PowerShell 7 is already installed"
	else
		info "*** Installing PowerShell 7.6.8..."
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget < /dev/null
		wget https://github.com/PowerShell/PowerShell/releases/download/v7.6.8/powershell-lts_7.6.8-1.deb_amd64.deb
		sudo DEBIAN_FRONTEND=noninteractive dpkg -i powershell-lts_7.6.8-1.deb_amd64.deb < /dev/null
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -f < /dev/null
		rm powershell-lts_7.6.8-1.deb_amd64.deb
	fi
fi

#-------------------------------------------------------------
## Visual Studio Code 1.104.0 (may need to update often)
#-------------------------------------------------------------

if [ "$INSTALL_VSCODE" = true ]; then
	FILE="/usr/share/code/code"
	if [ -f "$FILE" ]; then
		log "*** Visual Studio Code is already installed"
	else
		info "*** Installing Visual Studio Code from Microsoft apt repository..."
		sudo DEBIAN_FRONTEND=noninteractive apt install -y curl ca-certificates gnupg < /dev/null
		sudo install -d -m 0755 /etc/apt/keyrings
		curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
			| gpg --dearmor \
			| sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
		sudo chmod a+r /etc/apt/keyrings/packages.microsoft.gpg
		echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
			| sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
		safe_apt_update
		sudo DEBIAN_FRONTEND=noninteractive apt install -y code < /dev/null
	fi
fi

#-------------------------------------------------------------
## VirtualBox 7.2.20 (may need to update often)
#-------------------------------------------------------------

if [ "$INSTALL_VIRTUALBOX" = true ]; then
	FILE="/bin/VBox"
	if [ -f "$FILE" ]; then
		log "*** VirtualBox 7 is already installed"
	else
		info "*** Installing VirtualBox 7.2.20 ..."
		wget https://download.virtualbox.org/virtualbox/7.2.20/virtualbox-7.2_7.2.20-175154~Ubuntu~noble_amd64.deb
		sudo DEBIAN_FRONTEND=noninteractive apt install ./virtualbox-7.2_7.2.20-175154~Ubuntu~noble_amd64.deb -y < /dev/null
		rm virtualbox-7.2_7.2.20-175154~Ubuntu~noble_amd64.deb
	fi
fi

if command -v vboxmanage >/dev/null 2>&1; then
	VIRTUALBOX_AVAILABLE=true
else
	INSTALL_APPLET_VBOX=false
	INSTALL_EXTENSION_VBOX=false
fi

info "*** VirtualBox feature status: host-install=$INSTALL_VIRTUALBOX, available=$VIRTUALBOX_AVAILABLE, applet=$INSTALL_APPLET_VBOX, extension=$INSTALL_EXTENSION_VBOX"

#-------------------------------------------------------------
## Flatpak applications
#-------------------------------------------------------------

for app in "${flatpak_apps[@]}"; do
	if flatpak list | grep -q "$app"; then
		log "*** Flatpak application $app is already installed"
		continue
	else
		info "*** Installing Flatpak application: $app"
		flatpak install "$app" -y < /dev/null
	fi
done

#-------------------------------------------------------------
## System Configuration changes
#-------------------------------------------------------------

if [ "$ENABLE_FIREWALL" = true ]; then
	# check if firewall is enabled
	if sudo ufw status | grep -q "Status: active"; then
		log "*** Firewall is already enabled"
	else
		info "*** Firewall is not enabled, enabling now..."
		sudo ufw enable
		info "*** Enabling firewall..."
	fi
fi

info "*** Checking for updates..."
#sudo nala update && sudo apt upgrade -y
sudo nala upgrade -y < /dev/null
flatpak update -y < /dev/null

#-------------------------------------------------------------
## Themes and Icons
#-------------------------------------------------------------

FILE="/usr/share/icons/Papirus-Dark/index.theme"
if [ -f "$FILE" ]; then
	log "*** Papirus-Dark icons already installed"
	#echo -e "${GREEN}*** Papirus-Dark icons already installed${NC}"
else
	#echo -e "${YELLOW}*** Downloading Papirus-Dark theme...${NC}"
	info "*** Downloading Papirus-Dark theme..."
	sudo DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common < /dev/null
	sudo DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:papirus/papirus -y < /dev/null
	safe_apt_update
	sudo DEBIAN_FRONTEND=noninteractive apt install papirus-icon-theme -y < /dev/null
	info "*** Setting Papirus-Dark as icon theme"
	gsettings set org.cinnamon.desktop.interface icon-theme "Papirus-Dark"
fi

DESKTOP_THEME=$(gsettings get org.cinnamon.desktop.interface gtk-theme)
if [[ "$DESKTOP_THEME" == *"Mint-Y-Dark"* ]]; then
	log "*** Current theme is already: Mint-Y-Dark"
else
	info "*** Setting theme: Mint-Y-Dark"
	gsettings set org.cinnamon.desktop.interface gtk-theme "Mint-Y-Dark-Blue"
	gsettings set org.cinnamon.desktop.interface cursor-theme "Breeze"
	gsettings set org.cinnamon.desktop.interface icon-theme "Papirus-Dark"
fi

#-------------------------------------------------------------
## Nemo File Manager
#-------------------------------------------------------------

if [ "$CONFIGURE_NEMO" = true ]; then
	info "*** Applying Nemo file manager preferences..."
	gsettings set org.nemo.preferences show-hidden-files true
	gsettings set org.nemo.list-view default-visible-columns "['name', 'size', 'type', 'date_modified', 'date_created', 'owner', 'permissions']"
	gsettings set org.nemo.preferences show-new-folder-icon-toolbar true
	gsettings set org.nemo.preferences show-home-icon-toolbar true
	gsettings set org.nemo.preferences show-open-in-terminal-toolbar true
	gsettings set org.nemo.preferences.menu-config selection-menu-copy-to true
	gsettings set org.nemo.preferences.menu-config selection-menu-move-to true
fi

#-------------------------------------------------------------
## Applets
#-------------------------------------------------------------

if [ "$INSTALL_APPLETS" = true ]; then
	info "*** Installing Cinnamon Applets..."
	cd ~/.local/share/cinnamon/applets/
	FILE="weather@mockturtl/metadata.json"
	if [ -f "$FILE" ]; then
		log "*** Weather applet already installed"
	else
		info "*** Downloading applet: Weather..."
		wget https://cinnamon-spices.linuxmint.com/files/applets/weather@mockturtl.zip && unzip weather@mockturtl.zip
		rm weather@mockturtl.zip*
	fi

	if [ "$INSTALL_APPLET_VBOX" = true ] && [ "$VIRTUALBOX_AVAILABLE" = true ]; then
		VFILE="/usr/bin/vboxmanage"
		if [ -f "$VFILE" ]; then
			FILE="vboxlauncher@mockturtl/metadata.json"
			if [ -f "$FILE" ]; then
				log "*** VBox Launcher applet already installed"
			else
				info "*** Downloading applet: VBox Launcher..."
				wget https://cinnamon-spices.linuxmint.com/files/applets/vboxlauncher@mockturtl.zip && unzip vboxlauncher@mockturtl.zip
				rm vboxlauncher@mockturtl.zip*
			fi
		fi
	fi

	FILE="Cinnamenu@json/metadata.json"
	if [ -f "$FILE" ]; then
		log "*** Cinnamenu already installed"
	else
		info "*** Downloading Cinnamenu..."
		wget https://cinnamon-spices.linuxmint.com/files/applets/Cinnamenu@json.zip && unzip Cinnamenu@json.zip
		rm Cinnamenu@json.zip*
	fi

	UUID="Cinnamenu@json"
	GROUPED_WINDOWS_UUID="grouped-window-list@cinnamon.org"
	CALENDAR_UUID="calendar@cinnamon.org"
	BACKUP="$HOME/cinnamon-enabled-applets.backup"
	SPICES_DIR="$HOME/.config/cinnamon/spices/$UUID"
	SPICES_DIR_ALT="$HOME/.cinnamon/configs/$UUID"
	GROUPED_SPICES_DIR="$HOME/.config/cinnamon/spices/$GROUPED_WINDOWS_UUID"
	CALENDAR_SPICES_DIR="$HOME/.config/cinnamon/spices/$CALENDAR_UUID"
	CALENDAR_SPICES_DIR_ALT="$HOME/.cinnamon/configs/$CALENDAR_UUID"
	CINNAMENU_INSTANCE_FALLBACK="$(
		find "$SPICES_DIR" -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2>/dev/null \
			| sed 's/\.json$//' \
			| head -n 1
	)"
	GROUPED_INSTANCE_FALLBACK="$(
		find "$GROUPED_SPICES_DIR" -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2>/dev/null \
			| sed 's/\.json$//' \
			| head -n 1
	)"
	[ -z "$CINNAMENU_INSTANCE_FALLBACK" ] && CINNAMENU_INSTANCE_FALLBACK="1"
	[ -z "$GROUPED_INSTANCE_FALLBACK" ] && GROUPED_INSTANCE_FALLBACK="1"

	info "*** Updating panel layout: center=Cinnamenu+Grouped Windows List, others=right..."
	CURRENT_APPLETS="$(gsettings get org.cinnamon enabled-applets)"
	UPDATED_APPLETS="$(python3 - "$CURRENT_APPLETS" "$UUID" "$GROUPED_WINDOWS_UUID" "$CINNAMENU_INSTANCE_FALLBACK" "$GROUPED_INSTANCE_FALLBACK" <<'PY'
import ast
import sys

items = ast.literal_eval(sys.argv[1])
cinnamenu_uuid = sys.argv[2]
grouped_windows_uuid = sys.argv[3]
cinnamenu_fallback_instance = sys.argv[4]
grouped_fallback_instance = sys.argv[5]

other_applets = []
target_panel = None
cinnamenu_suffix = []
grouped_windows_suffix = []
cinnamenu_found = False
grouped_windows_found = False

for item in items:
    fields = item.split(":")
    if len(fields) < 4:
        raise SystemExit(f"Unexpected applet entry: {item}")

    panel, zone, position, uuid = fields[:4]
    suffix = fields[4:]

    if uuid in ("menu@cinnamon.org", cinnamenu_uuid):
        if not cinnamenu_found:
            cinnamenu_found = True
            cinnamenu_suffix = suffix
            if not cinnamenu_suffix:
                cinnamenu_suffix = [cinnamenu_fallback_instance]
            if target_panel is None:
                target_panel = panel
        continue

    if uuid == grouped_windows_uuid:
        if not grouped_windows_found:
            grouped_windows_found = True
            grouped_windows_suffix = suffix
            if not grouped_windows_suffix:
                grouped_windows_suffix = [grouped_fallback_instance]
            if target_panel is None:
                target_panel = panel
        continue

    other_applets.append((panel, uuid, suffix))

if target_panel is None:
    target_panel = "1"

result = [
    ":".join([target_panel, "center", "0", cinnamenu_uuid, *cinnamenu_suffix]),
    ":".join([target_panel, "center", "1", grouped_windows_uuid, *grouped_windows_suffix]),
]

right_position = 0
for _panel, uuid, suffix in other_applets:
    result.append(":".join([target_panel, "right", str(right_position), uuid, *suffix]))
    right_position += 1

print(repr(result))
PY
)"
	if [ "$CURRENT_APPLETS" != "$UPDATED_APPLETS" ]; then
		info "*** Backing up current Cinnamon panel applet layout..."
		printf '%s\n' "$CURRENT_APPLETS" > "$BACKUP"
		gsettings set org.cinnamon enabled-applets "$UPDATED_APPLETS"
	else
		log "*** Panel layout already matches desired configuration"
	fi

	info "*** Resolving Cinnamenu settings files..."
	readarray -t CINNAMENU_INSTANCE_IDS < <(python3 - "$UPDATED_APPLETS" "$UUID" <<'PY'
import ast
import sys

items = ast.literal_eval(sys.argv[1])
uuid = sys.argv[2]
seen = set()

for item in items:
    fields = item.split(":")
    if len(fields) >= 5 and fields[3] == uuid:
        instance_id = fields[4]
        if instance_id not in seen:
            print(instance_id)
            seen.add(instance_id)
PY
)
	SETTINGS_FILES=()
	declare -A CINNAMENU_SETTINGS_FILE_SET=()

	mkdir -p "$SPICES_DIR"
	for instance_id in "${CINNAMENU_INSTANCE_IDS[@]}"; do
		[ -n "$instance_id" ] || continue
		found_instance_file=false
		for settings_dir in "$SPICES_DIR" "$SPICES_DIR_ALT"; do
			settings_file="$settings_dir/$instance_id.json"
			if [ -f "$settings_file" ]; then
				if [ -z "${CINNAMENU_SETTINGS_FILE_SET[$settings_file]+x}" ]; then
					SETTINGS_FILES+=("$settings_file")
					CINNAMENU_SETTINGS_FILE_SET["$settings_file"]=1
				fi
				found_instance_file=true
			fi
		done

		if [ "$found_instance_file" = false ]; then
			settings_file="$SPICES_DIR/$instance_id.json"
			printf '{}\n' > "$settings_file"
			SETTINGS_FILES+=("$settings_file")
			CINNAMENU_SETTINGS_FILE_SET["$settings_file"]=1
			info "*** Created missing Cinnamenu settings file: $settings_file"
		fi
	done

	for settings_dir in "$SPICES_DIR" "$SPICES_DIR_ALT"; do
		while IFS= read -r -d '' settings_file; do
			if [ -z "${CINNAMENU_SETTINGS_FILE_SET[$settings_file]+x}" ]; then
				SETTINGS_FILES+=("$settings_file")
				CINNAMENU_SETTINGS_FILE_SET["$settings_file"]=1
			fi
		done < <(find "$settings_dir" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)
	done

	if [ "${#SETTINGS_FILES[@]}" -gt 0 ]; then
		info "*** Applying Cinnamenu icon and caption settings to all instances..."
		for SETTINGS_FILE in "${SETTINGS_FILES[@]}"; do
			cp -a "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
			python3 - "$SETTINGS_FILE" "$CINNAMENU_ICON" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
menu_icon = sys.argv[2]
settings = json.loads(path.read_text(encoding="utf-8"))

def set_setting(key, value):
    entry = settings.get(key)
    if isinstance(entry, dict) and "value" in entry:
        entry["value"] = value
    else:
        settings[key] = value

set_setting("menu-label", "")
set_setting("menu-icon-custom", True)
set_setting("menu-icon", menu_icon)

path.write_text(
    json.dumps(settings, indent=4, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
		done
	else
		warn "*** Cinnamenu settings files not found under $SPICES_DIR or $SPICES_DIR_ALT; skipping icon/caption customization"
	fi

	info "*** Resolving Grouped Window List settings files..."
	readarray -d '' GROUPED_SETTINGS_FILES < <(find "$GROUPED_SPICES_DIR" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

	if [ "${#GROUPED_SETTINGS_FILES[@]}" -gt 0 ]; then
		info "*** Pinning launchers in Grouped Window List..."
		for GROUPED_SETTINGS_FILE in "${GROUPED_SETTINGS_FILES[@]}"; do
			cp -a "$GROUPED_SETTINGS_FILE" "$GROUPED_SETTINGS_FILE.bak"
			python3 - "$GROUPED_SETTINGS_FILE" "${GROUPED_WINDOW_PINNED_LAUNCHERS[@]}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
configured_launchers = sys.argv[2:]
settings = json.loads(path.read_text(encoding="utf-8"))

desktop_dirs = [
    Path.home() / ".local/share/applications",
    Path("/usr/share/applications"),
    Path.home() / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
]
available_desktop_files = {
    entry.name
    for desktop_dir in desktop_dirs
    if desktop_dir.is_dir()
    for entry in desktop_dir.glob("*.desktop")
}

candidate_map = {
    "drawio.desktop": ["drawio.desktop", "com.jgraph.drawio.desktop", "com.jgraph.drawio.desktop:flatpak"],
    "code.desktop": ["code.desktop", "com.microsoft.VSCode.desktop"],
    "brave-browser.desktop": ["brave-browser.desktop", "com.brave.Browser.desktop:flatpak", "com.brave.Browser.desktop"],
    "com.github.IsmaelMartinez.teams_for_linux.desktop:flatpak": [
        "com.github.IsmaelMartinez.teams_for_linux.desktop:flatpak",
        "com.github.IsmaelMartinez.teams_for_linux.desktop",
    ],
}

if not configured_launchers:
    configured_launchers = [
        "libreoffice-writer.desktop",
        "libreoffice-calc.desktop",
        "libreoffice-impress.desktop",
        "drawio.desktop",
        "code.desktop",
        "brave-browser.desktop",
        "com.github.IsmaelMartinez.teams_for_linux.desktop:flatpak",
    ]

resolved_required = []
for launcher_id in configured_launchers:
    candidates = candidate_map.get(launcher_id, [launcher_id])
    selected = None
    for candidate in candidates:
        desktop_name = candidate.removesuffix(":flatpak")
        if desktop_name in available_desktop_files:
            selected = candidate
            break
    resolved_required.append(selected or launcher_id)

entry = settings.get("pinned-apps")
if isinstance(entry, dict) and "value" in entry and isinstance(entry["value"], list):
    current = [item for item in entry["value"] if item not in resolved_required]
    entry["value"] = [*resolved_required, *current]
elif isinstance(entry, list):
    current = [item for item in entry if item not in resolved_required]
    settings["pinned-apps"] = [*resolved_required, *current]
else:
    settings["pinned-apps"] = {"value": resolved_required}

path.write_text(
    json.dumps(settings, indent=4, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
		done
	else
		warn "*** Grouped Window List settings file not found under $GROUPED_SPICES_DIR; skipping launcher pinning"
	fi

	if [ "$CALENDAR_USE_CUSTOM_FORMAT" = true ]; then
		info "*** Resolving Calendar applet settings files..."
		readarray -t CALENDAR_INSTANCE_IDS < <(python3 - "$UPDATED_APPLETS" "$CALENDAR_UUID" <<'PY'
import ast
import sys

items = ast.literal_eval(sys.argv[1])
uuid = sys.argv[2]
seen = set()

for item in items:
    fields = item.split(":")
    if len(fields) >= 5 and fields[3] == uuid:
        instance_id = fields[4]
        if instance_id not in seen:
            print(instance_id)
            seen.add(instance_id)
PY
)
		CALENDAR_SETTINGS_FILES=()
		declare -A CALENDAR_SETTINGS_FILE_SET=()

		mkdir -p "$CALENDAR_SPICES_DIR"
		for instance_id in "${CALENDAR_INSTANCE_IDS[@]}"; do
			[ -n "$instance_id" ] || continue
			found_instance_file=false
			for settings_dir in "$CALENDAR_SPICES_DIR" "$CALENDAR_SPICES_DIR_ALT"; do
				settings_file="$settings_dir/$instance_id.json"
				if [ -f "$settings_file" ]; then
					if [ -z "${CALENDAR_SETTINGS_FILE_SET[$settings_file]+x}" ]; then
						CALENDAR_SETTINGS_FILES+=("$settings_file")
						CALENDAR_SETTINGS_FILE_SET["$settings_file"]=1
					fi
					found_instance_file=true
				fi
			done

			if [ "$found_instance_file" = false ]; then
				settings_file="$CALENDAR_SPICES_DIR/$instance_id.json"
				printf '{}\n' > "$settings_file"
				CALENDAR_SETTINGS_FILES+=("$settings_file")
				CALENDAR_SETTINGS_FILE_SET["$settings_file"]=1
				info "*** Created missing Calendar settings file: $settings_file"
			fi
		done

		for settings_dir in "$CALENDAR_SPICES_DIR" "$CALENDAR_SPICES_DIR_ALT"; do
			while IFS= read -r -d '' settings_file; do
				if [ -z "${CALENDAR_SETTINGS_FILE_SET[$settings_file]+x}" ]; then
					CALENDAR_SETTINGS_FILES+=("$settings_file")
					CALENDAR_SETTINGS_FILE_SET["$settings_file"]=1
				fi
			done < <(find "$settings_dir" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)
		done

		if [ "${#CALENDAR_SETTINGS_FILES[@]}" -gt 0 ]; then
			info "*** Enabling custom date format in Calendar applet..."
			for CALENDAR_SETTINGS_FILE in "${CALENDAR_SETTINGS_FILES[@]}"; do
				cp -a "$CALENDAR_SETTINGS_FILE" "$CALENDAR_SETTINGS_FILE.bak"
				python3 - "$CALENDAR_SETTINGS_FILE" "$CALENDAR_CUSTOM_FORMAT" "$CALENDAR_CUSTOM_TOOLTIP_FORMAT" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
calendar_custom_format = sys.argv[2]
calendar_custom_tooltip_format = sys.argv[3]
settings = json.loads(path.read_text(encoding="utf-8"))

entry = settings.get("use-custom-format")
if isinstance(entry, dict) and "value" in entry:
    entry["value"] = True
else:
    settings["use-custom-format"] = True

for key, value in (
    ("custom-format", calendar_custom_format),
    ("custom-tooltip-format", calendar_custom_tooltip_format),
):
    entry = settings.get(key)
    if isinstance(entry, dict) and "value" in entry:
        entry["value"] = value
    else:
        settings[key] = value

path.write_text(
    json.dumps(settings, indent=4, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
			done
		else
			warn "*** Calendar settings files not found under $CALENDAR_SPICES_DIR or $CALENDAR_SPICES_DIR_ALT; skipping custom date format toggle"
		fi
	fi

	FILE="sound150@claudiux/metadata.json"
	if [ -f "$FILE" ]; then
		log "*** Enhanced Sound Applet already installed"
	else
		info "*** Downloading Enhanced Sound Applet..."
		wget https://cinnamon-spices.linuxmint.com/files/applets/sound150@claudiux.zip && unzip sound150@claudiux.zip
		rm sound150@claudiux.zip*
	fi
fi

#-------------------------------------------------------------
## Actions
#-------------------------------------------------------------


#-------------------------------------------------------------
## Extensions
#-------------------------------------------------------------

if [ "$INSTALL_EXTENSIONS" = true ]; then
	log "*** Installing Cinnamon Extensions..."
	cd ~/.local/share/cinnamon/extensions/
	FILE="copy-path-to-clipboard@claudiux/metadata.json"
	if [ -f "$FILE" ]; then
		log "*** Extension: copy-path-to-clipboard already installed"
	else
		info "*** Downloading extension: copy-path-to-clipboard..."
		wget https://cinnamon-spices.linuxmint.com/files/actions/copy-path-to-clipboard@claudiux.zip && unzip copy-path-to-clipboard@claudiux.zip
		rm copy-path-to-clipboard@claudiux.zip*
	fi

	if [ "$INSTALL_EXTENSION_VBOX" = true ] && [ "$VIRTUALBOX_AVAILABLE" = true ]; then
		FILE="vbox@claudiux/metadata.json"
		if [ -f "$FILE" ]; then
			log "*** Extension: vbox already installed"
		else
			info "*** Downloading extension: vbox..."
			wget https://cinnamon-spices.linuxmint.com/files/extensions/vbox@claudiux.zip && unzip vbox@claudiux.zip
			rm vbox@claudiux.zip*
		fi
	fi
fi

#-------------------------------------------------------------
# Download wallpaper and set active
#-------------------------------------------------------------

if [ "$INSTALL_WALLPAPER" = true ]; then
	step "Downloading wallpaper to $WALLPAPER"
	mkdir -p "$WALLPAPER_DIR"
	curl -fL --retry 2 "$WALLPAPER_URL" -o "$WALLPAPER"
	status "Wallpaper downloaded."
	# Set the downloaded wallpaper as the desktop background
	gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER"
fi

#-------------------------------------------------------------
## Additional Utilities and AppImages
#-------------------------------------------------------------

mkdir -p "$HOME/Applications"
if [ "$INSTALL_ARTCRAFT" = true ]; then
	if [ ! -f "$ARTCRAFT_PATH" ]; then
		info "*** Downloading ArtCraft Launcher..."
		curl -fL --retry 2 "$ARTCRAFT_URI" -o "$ARTCRAFT_PATH"
		chmod +x "$ARTCRAFT_PATH"
	fi

	if [ -f "$ARTCRAFT_PATH" ]; then
		if [ -f "$ARTCRAFT_ONCE_DONE_MARKER" ]; then
			log "*** One-time ArtCraft launch already completed on a previous run"
		elif [ -f "$ARTCRAFT_ONCE_DESKTOP" ] && [ -f "$ARTCRAFT_ONCE_SCRIPT" ]; then
			log "*** One-time ArtCraft launch is already scheduled for next login"
		else
			info "*** Scheduling one-time ArtCraft launch for next login..."
			mkdir -p "$HOME/.local/bin" "$HOME/.config/autostart" "$(dirname "$ARTCRAFT_ONCE_DONE_MARKER")"
			cat > "$ARTCRAFT_ONCE_SCRIPT" <<EOF
#!/bin/bash
set -e
DESKTOP_FILE="$ARTCRAFT_ONCE_DESKTOP"
SCRIPT_FILE="$ARTCRAFT_ONCE_SCRIPT"
APPIMAGE="$ARTCRAFT_PATH"
MARKER_FILE="$ARTCRAFT_ONCE_DONE_MARKER"

rm -f "\$DESKTOP_FILE"
if [ -x "\$APPIMAGE" ]; then
	nohup "\$APPIMAGE" >/dev/null 2>&1 &
fi
mkdir -p "\$(dirname "\$MARKER_FILE")"
touch "\$MARKER_FILE"
rm -f "\$SCRIPT_FILE"
EOF
			chmod +x "$ARTCRAFT_ONCE_SCRIPT"

			cat > "$ARTCRAFT_ONCE_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Mint Setup One-Time ArtCraft Launch
Comment=Launch ArtCraft once after next login
Exec=/bin/bash -lc "$ARTCRAFT_ONCE_SCRIPT"
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
		fi
	else
		warn "*** ArtCraft launcher file not found at $ARTCRAFT_PATH; skipping one-time launch setup"
	fi
fi
export PATH="$HOME/Applications:$PATH"

if ! command -v drawio &> /dev/null; then
	DRAWIO_URI="https://github.com/jgraph/drawio-desktop/releases/download/v32.5.5/drawio-amd64-32.5.5.deb"
	DRAWIO_PATH="$HOME/Applications/$(basename "$DRAWIO_URI")"
	if [ ! -f "$DRAWIO_PATH" ]; then
		info "*** Downloading Draw.io 32.5.5 ..."
		curl -fL --retry 2 "$DRAWIO_URI" -o "$DRAWIO_PATH"
		sudo DEBIAN_FRONTEND=noninteractive dpkg -i "$DRAWIO_PATH" < /dev/null
	fi
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y < /dev/null
fi

#FILE="~/.cargo/bin/oniux"
#if [ -f "$FILE" ]; then
#	log "*** Oniux is already installed."
#else
#	info "*** Installing Oniux..."
#	cargo install --git https://gitlab.torproject.org/tpo/core/oniux --tag v0.4.0 oniux
#	info "Oniux installed successfully. Use: oniux <command> to launch with Tor envelope."
#fi

log "*** Applying system tweaks..."

if [ "$VIRTUALBOX_AVAILABLE" = true ]; then
	VFILE="/usr/bin/vboxmanage"
	if [ -f "$VFILE" ]; then
		# Disable KVM modules to avoid VirtualBox conflicts
		info "*** Disabling KVM modules to avoid VirtualBox conflicts..."
	sudo tee /etc/modprobe.d/blacklist-kvm.conf > /dev/null << 'EOF'
blacklist kvm
blacklist kvm_intel
blacklist kvm_amd
EOF
		log "*** Disabling KVM modules..."
		sudo update-initramfs -u
	fi
fi

log "Setup is complete!. Please restart your system to apply all changes."
if [ -r /dev/tty ]; then
	read -r -p "Reboot now? Press Y to reboot immediately, or any other key to skip: " REBOOT_CHOICE < /dev/tty
	if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
		info "*** Rebooting now..."
		sudo reboot
	else
		info "*** Reboot skipped. Please reboot later to apply all changes."
	fi
else
	info "*** No controlling terminal detected; skipping reboot prompt."
fi