#!/bin/bash
#-------------------------------------------------------------
# Linuxmint setup script by Skatterbrainz
# version: 1.5, 7/26/2025
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
	"adwaita-icon-theme"
	"glogg"
	"kcolorchooser"
	"kpat"
	"nala"
	"shutter"
	"yad"
	"yt-dlp"
	"cargo"
	"easytag"
	"jq"
	"smartmontools"
	"gsmartcontrol"
)

for package in "${aptpackages[@]}"; do
	info "*** Installing apt package: $package"
	sudo nala install "$package" -y
done

#-------------------------------------------------------------
## FastFetch
#-------------------------------------------------------------
cd ~/Downloads

FILE="/bin/fastfetch"
if [ -f "$FILE" ]; then
	log "*** FastFetch is already installed"
else
	info "*** Installing FastFetch..."
	sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
	sudo apt update
	sudo nala install fastfetch -y
fi

#-------------------------------------------------------------
## PowerShell 7.5.3 (may need to update often)
#-------------------------------------------------------------

FILE="/opt/microsoft/powershell/7/pwsh"
if [ -f "$FILE" ]; then
	log "*** PowerShell 7 is already installed"
else
	info "*** Installing PowerShell 7..."
	sudo apt-get install -y wget
	wget https://github.com/PowerShell/PowerShell/releases/download/v7.5.3/powershell_7.5.3-1.deb_amd64.deb
	sudo dpkg -i powershell_7.5.3-1.deb_amd64.deb
	sudo apt-get install -f
	rm powershell_7.5.3-1.deb_amd64.deb
fi

#-------------------------------------------------------------
## Visual Studio Code 1.104.0 (may need to update often)
#-------------------------------------------------------------

FILE="/usr/share/code/code"
if [ -f "$FILE" ]; then
	log "*** Visual Studio Code is already installed"
else
	info "*** Installing Visual Studio Code..."
	wget https://vscode.download.prss.microsoft.com/dbazure/download/stable/f220831ea2d946c0dcb0f3eaa480eb435a2c1260/code_1.104.0-1757488003_amd64.deb
	sudo apt install ./code_1.104.0-1757488003_amd64.deb
	rm ./code_1.104.0-1757488003_amd64.deb
fi

#-------------------------------------------------------------
## VirtualBox 7.2.4 (may need to update often)
#-------------------------------------------------------------

FILE="/bin/VBox"
if [ -f "$FILE" ]; then
	log "*** VirtualBox 7 is already installed"
else
	info "*** Installing VirtualBox..."
	wget https://download.virtualbox.org/virtualbox/7.2.4/virtualbox-7.2_7.2.4-170995~Ubuntu~noble_amd64.deb
	sudo apt install ./virtualbox-7.2_7.2.4-170995~Ubuntu~noble_amd64.deb -y
	rm virtualbox-7.2_7.2.4-170995~Ubuntu~noble_amd64.deb
fi

#-------------------------------------------------------------
## Warp Terminal (see https://www.warp.dev/download)
#-------------------------------------------------------------

FILE="/usr/bin/warp-terminal"
if [ -f "$FILE" ]; then
	log "*** Warp Terminal is already installed"
else
	info "*** Installing Warp Terminal..."
	sudo apt install -y wget
	wget https://releases.warp.dev/stable/v0.2026.01.21.08.14.stable_03/warp-terminal_0.2026.01.21.08.14.stable.03_amd64.deb
	sudo dpkg -i ./warp-terminal_0.2026.01.21.08.14.stable.03_amd64.deb
	sudo apt-get install -f
	rm ./warp-terminal_0.2026.01.21.08.14.stable.03_amd64.deb
fi

#-------------------------------------------------------------
## Flatpak applications
#-------------------------------------------------------------

declare -a flatpak_apps=(
	"com.bitwarden.desktop"
	"com.brave.Browser"
	"com-github.hluk.copyq"
	"com.jgraph.drawio.desktop"
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
	"org.kdi.kleopatra"
	"net.puddletag.puddletag"
	"md.obsidian.Obsidian"
	"org.gnome.Mahjongg"
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
## Additional Utilities
#-------------------------------------------------------------

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