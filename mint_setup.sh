#!/bin/bash
#-------------------------------------------------------------
# Linux Mint setup script by Skatterbrainz
# version: 1.6, 10/22/2026
#-------------------------------------------------------------
# To invoke this from a terminal using wget or curl:
# wget -O /tmp/mint_setup.sh <URL> && /tmp/mint_setup.sh
#-------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
WALLPAPER_URL="https://raw.githubusercontent.com/Skatterbrainz/Garage/refs/heads/master/qYeaEQC-water-droplets-wallpaper.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER="$WALLPAPER_DIR/qYeaEQC-water-droplets-wallpaper.jpg"
ARTCRAFT_URI="https://github.com/storytold/craft-launcher/releases/download/v0.6.1/artcraft-launcher-0.6.1-linux-x86_64.AppImage"
ARTCRAFT_PATH="$HOME/AppImages/$(basename "$ARTCRAFT_URI")"
mkdir -p "$HOME/AppImages"

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
fi

# Check if running on Linux Mint
if ! grep -q "Linux Mint" /etc/os-release; then
	warn "This script was designed for Linux Mint but will attempt to run anyway"
fi

log "Starting system setup..."

sudo apt update

FILE="/usr/bin/nala"
if [ -f "$FILE" ]; then
	log "*** Nala is already installed"
else
	info "*** Installing Nala..."
	sudo apt install -y nala
	info "*** Updating Nala repository list..."
	sudo nala fetch --auto --fetches 8 --country US
	log "*** Nala installed successfully"
fi

#-------------------------------------------------------------
## Apt packages 
#-------------------------------------------------------------

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

for package in "${aptpackages[@]}"; do
	info "*** Installing apt package: $package"
	sudo nala install "$package" -y
done

#-------------------------------------------------------------
## Brave Browser
#-------------------------------------------------------------

FILE="/usr/bin/brave-browser"
if [ -f "$FILE" ]; then
	log "*** Brave Browser is already installed"
else
	info "*** Installing Brave Browser..."
	curl -fsS https://dl.brave.com/install.sh | sh
fi

#-------------------------------------------------------------
## FastFetch
#-------------------------------------------------------------
cd ~/Downloads

# FILE="/bin/fastfetch"
# if [ -f "$FILE" ]; then
# 	log "*** FastFetch is already installed"
# else
# 	info "*** Installing FastFetch..."
# 	sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
# 	sudo apt update
# 	sudo nala install fastfetch -y
# fi

#-------------------------------------------------------------
## PowerShell 7.6.8 (may need to update often)
#-------------------------------------------------------------

FILE="/opt/microsoft/powershell/7/pwsh"
if [ -f "$FILE" ]; then
	log "*** PowerShell 7 is already installed"
else
	info "*** Installing PowerShell 7.6.8..."
	sudo apt-get install -y wget
	wget https://github.com/PowerShell/PowerShell/releases/download/v7.6.8/powershell-lts_7.6.8-1.deb_amd64.deb
	sudo dpkg -i powershell-lts_7.6.8-1.deb_amd64.deb
	sudo apt-get install -f
	rm powershell-lts_7.6.8-1.deb_amd64.deb
fi

#-------------------------------------------------------------
## Visual Studio Code 1.104.0 (may need to update often)
#-------------------------------------------------------------

FILE="/usr/share/code/code"
if [ -f "$FILE" ]; then
	log "*** Visual Studio Code is already installed"
else
	info "*** Installing Visual Studio Code 1.143.1..."
	wget https://vscode.download.prss.microsoft.com/dbazure/download/stable/e646868227c3e3a9e3f24277c8c7220be42c0be7/code_1.143.1-1792691907_amd64.deb
	sudo apt install ./code_1.143.1-1792691907_amd64.deb
	rm ./code_1.143.1-1792691907_amd64.deb
fi

#-------------------------------------------------------------
## VirtualBox 7.2.20 (may need to update often)
#-------------------------------------------------------------

# Skip this if the machine is a VM guest running inside VirtualBox
if systemd-detect-virt -q && [ "$(systemd-detect-virt)" = "oracle" ]; then
	log "*** Running inside VirtualBox VM, skipping VirtualBox installation"
else
	FILE="/bin/VBox"
	if [ -f "$FILE" ]; then
		log "*** VirtualBox 7 is already installed"
	else
		info "*** Installing VirtualBox 7.2.20 ..."
		wget https://download.virtualbox.org/virtualbox/7.2.20/virtualbox-7.2_7.2.20-175154~Ubuntu~noble_amd64.deb
		sudo apt install ./virtualbox-7.2_7.2.20-175154~Ubuntu~noble_amd64.deb -y
		rm virtualbox-7.2_7.2.20-175154~Ubuntu~noble_amd64.deb
	fi
fi

#-------------------------------------------------------------
## Warp Terminal (see https://www.warp.dev/download)
#-------------------------------------------------------------

# FILE="/usr/bin/warp-terminal"
# if [ -f "$FILE" ]; then
# 	log "*** Warp Terminal is already installed"
# else
# 	info "*** Installing Warp Terminal..."
# 	sudo apt install -y wget
# 	wget https://releases.warp.dev/stable/v0.2026.01.21.08.14.stable_03/warp-terminal_0.2026.01.21.08.14.stable.03_amd64.deb
# 	sudo dpkg -i ./warp-terminal_0.2026.01.21.08.14.stable.03_amd64.deb
# 	sudo apt-get install -f
# 	rm ./warp-terminal_0.2026.01.21.08.14.stable.03_amd64.deb
# fi

#-------------------------------------------------------------
## Flatpak applications
#-------------------------------------------------------------

declare -a flatpak_apps=(
	"com.bitwarden.desktop"
	"com-github.hluk.copyq"
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
#	"org.gnome.Mahjongg"
	"com.github.wwmm.easyeffects"
	"com.getpostman.Postman"
	"io.github.shiftey.Desktop"
)

for app in "${flatpak_apps[@]}"; do
	if flatpak list | grep -q "$app"; then
		log "*** Flatpak application $app is already installed"
		continue
	else
		info "*** Installing Flatpak application: $app"
		flatpak install "$app" -y
	fi
done

#-------------------------------------------------------------
## System Configuration changes
#-------------------------------------------------------------

# check if firewall is enabled
if sudo ufw status | grep -q "Status: active"; then
	log "*** Firewall is already enabled"
else
	info "*** Firewall is not enabled, enabling now..."
	info "*** Enabling firewall..."
fi

info "*** Checking for updates..."
#sudo nala update && sudo apt upgrade -y
sudo nala upgrade -y
flatpak update -y

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
	sudo apt install -y software-properties-common
	sudo add-apt-repository ppa:papirus/papirus -y
	sudo apt update && sudo apt install papirus-icon-theme -y
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
## Applets
#-------------------------------------------------------------

log "*** Setting applets..."
cd ~/.local/share/cinnamon/applets/
FILE="weather@mockturtl/metadata.json"
if [ -f "$FILE" ]; then
	log "*** Weather applet already installed"
else
	info "*** Downloading applet: Weather..."
	wget https://cinnamon-spices.linuxmint.com/files/applets/weather@mockturtl.zip && unzip weather@mockturtl.zip
	rm weather@mockturtl.zip*
fi

VFILE="/usr/bin/vboxmanage"
if [ -f "$VFILE" ]; then
	FILE="vboxlauncher@mockturtl/metadata.json"
	if [ -f "$FILE" ]; then
		log
	else
		info "*** Downloading applet: VBox Launcher..."
		wget https://cinnamon-spices.linuxmint.com/files/applets/vboxlauncher@mockturtl.zip && unzip vboxlauncher@mockturtl.zip
		rm vboxlauncher@mockturtl.zip*
	fi
else
	info "*** VBoxManage not found, installing VirtualBox applet..."
	sudo apt install -y virtualbox
fi

FILE="Cinnamenu@json/metadata.json"
if [ -f "$FILE" ]; then
	log "*** Cinnamenu already installed"
else
	info "*** Downloading Cinnamenu..."
	wget https://cinnamon-spices.linuxmint.com/files/applets/Cinnamenu@json.zip && unzip Cinnamenu@json.zip
	rm Cinnamenu@json.zip*
fi

FILE="sound150@claudiux/metadata.json"
if [ -f "$FILE" ]; then
	log "*** Enhanced Sound Applet already installed"
else
	info "*** Downloading Enhanced Sound Applet..."
	wget https://cinnamon-spices.linuxmint.com/files/applets/sound150@claudiux.zip && unzip sound150@claudiux.zip
	rm sound150@claudiux.zip*
fi

#-------------------------------------------------------------
## Actions
#-------------------------------------------------------------


#-------------------------------------------------------------
## Extensions
#-------------------------------------------------------------

cd ~/.local/share/cinnamon/extensions/
FILE="copy-path-to-clipboard@claudiux/metadata.json"
if [ -f "$FILE" ]; then
	log "*** Extension: copy-path-to-clipboard already installed"
else
	info "*** Downloading extension: copy-path-to-clipboard..."
	wget https://cinnamon-spices.linuxmint.com/files/actions/copy-path-to-clipboard@claudiux.zip && unzip copy-path-to-clipboard@claudiux.zip
	rm copy-path-to-clipboard@claudiux.zip*
fi

#-------------------------------------------------------------
# Download wallpaper
#-------------------------------------------------------------

step "Downloading wallpaper to $WALLPAPER"
mkdir -p "$WALLPAPER_DIR"
curl -fL --retry 2 "$WALLPAPER_URL" -o "$WALLPAPER"
status "Wallpaper downloaded."

# Set the downloaded wallpaper as the desktop background
gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER"

#-------------------------------------------------------------
## Additional Utilities and AppImages
#-------------------------------------------------------------

mkdir -p "$HOME/AppImages"

if [ ! -f "$ARTCRAFT_PATH" ]; then
	info "*** Downloading ArtCraft Launcher..."
	curl -fL --retry 2 "$ARTCRAFT_URI" -o "$ARTCRAFT_PATH"
	chmod +x "$ARTCRAFT_PATH"
fi
export PATH="$HOME/AppImages:$PATH"

# download and install WordCraft
WORDCRAFT_URI="https://github.com/storytold/wordcraft/releases/download/v0.10.0/wordcraft-0.10.0-linux-x86_64.AppImage"
WORDCRAFT_PATH="$HOME/AppImages/$(basename "$WORDCRAFT_URI")"
if [ ! -f "$WORDCRAFT_PATH" ]; then
	info "*** Downloading WordCraft..."
	curl -fL --retry 2 "$WORDCRAFT_URI" -o "$WORDCRAFT_PATH"
	chmod +x "$WORDCRAFT_PATH"
fi

# download and install PDFCraft
PDFCRAFT_URI="https://github.com/storytold/pdfcraft/releases/download/v0.13.0/pdfcraft-0.13.0-linux-x86_64.AppImage"
PDFCRAFT_PATH="$HOME/AppImages/$(basename "$PDFCRAFT_URI")"
if [ ! -f "$PDFCRAFT_PATH" ]; then
	info "*** Downloading PDFCraft..."
	curl -fL --retry 2 "$PDFCRAFT_URI" -o "$PDFCRAFT_PATH"
	chmod +x "$PDFCRAFT_PATH"
fi

# download and install GridCraft
GRIDCRAFT_URI="https://github.com/storytold/gridcraft/releases/download/v0.11.1/gridcraft-0.11.1-linux-x86_64.AppImage"
GRIDCRAFT_PATH="$HOME/AppImages/$(basename "$GRIDCRAFT_URI")"
if [ ! -f "$GRIDCRAFT_PATH" ]; then
	info "*** Downloading GridCraft..."
	curl -fL --retry 2 "$GRIDCRAFT_URI" -o "$GRIDCRAFT_PATH"
	chmod +x "$GRIDCRAFT_PATH"
fi

# download and install DeckCraft
DECKCRAFT_URI="https://github.com/storytold/deckcraft/releases/download/v0.10.0/deckcraft-0.10.0-linux-x86_64.AppImage"
DECKCRAFT_PATH="$HOME/AppImages/$(basename "$DECKCRAFT_URI")"
if [ ! -f "$DECKCRAFT_PATH" ]; then
	info "*** Downloading DeckCraft..."
	curl -fL --retry 2 "$DECKCRAFT_URI" -o "$DECKCRAFT_PATH"
	chmod +x "$DECKCRAFT_PATH"
fi

# download and install Draw.io
# DRAWIO_URI="https://github.com/jgraph/drawio-desktop/releases/download/v32.5.5/drawio-x86_64-32.5.5.AppImage"
# DRAWIO_PATH="$HOME/AppImages/$(basename "$DRAWIO_URI")"
# if [ ! -f "$DRAWIO_PATH" ]; then
# 	info "*** Downloading Draw.io..."
# 	curl -fL --retry 2 "$DRAWIO_URI" -o "$DRAWIO_PATH"
# 	chmod +x "$DRAWIO_PATH"
# fi

if ! command -v drawio &> /dev/null; then
	DRAWIO_URI="https://github.com/jgraph/drawio-desktop/releases/download/v32.5.5/drawio-amd64-32.5.5.deb"
	DRAWIO_PATH="$HOME/AppImages/$(basename "$DRAWIO_URI")"
	if [ ! -f "$DRAWIO_PATH" ]; then
		info "*** Downloading Draw.io 32.5.5 ..."
		curl -fL --retry 2 "$DRAWIO_URI" -o "$DRAWIO_PATH"
		sudo dpkg -i "$DRAWIO_PATH"
	fi
	sudo apt-get install -f -y
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

log "Setup is complete!. Please restart your system to apply all changes."