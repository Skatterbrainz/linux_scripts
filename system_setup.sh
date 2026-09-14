#!/bin/bash

# =============================================================================
# System Setup Script for Linux Mint
# Generated on: $(date)
# This script replicates the configuration of ds0934's Linux Mint system
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
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

# =============================================================================
# 1. Update system and install essential packages
# =============================================================================

log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

log "Installing essential development tools..."
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    make \
    gcc \
    rustc \
    cargo \
    npm \
    python3 \
    python3-pip \
    neofetch \
    openssh-client \
    rsync \
    7zip

# =============================================================================
# 2. Install major applications
# =============================================================================

log "Installing major applications..."

# Visual Studio Code
if ! command -v code &> /dev/null; then
    log "Installing Visual Studio Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install -y code
fi

# PowerShell
if ! command -v pwsh &> /dev/null; then
    log "Installing PowerShell..."
    wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt update
    sudo apt install -y powershell
    rm packages-microsoft-prod.deb
fi

# .NET SDK
if ! command -v dotnet &> /dev/null; then
    log "Installing .NET SDK..."
    sudo apt install -y dotnet-sdk-9.0
fi

# VirtualBox
if ! command -v virtualbox &> /dev/null; then
    log "Installing VirtualBox..."
    sudo apt install -y virtualbox-7.1
fi

# add PPA for LibreOffice
sudo add-apt-repository -y "https://ppa.launchpadcontent.net/libreoffice/libreoffice-still/ubuntu noble main"
sudo apt update

# LibreOffice (if not already installed)
sudo apt install -y \
    libreoffice-calc \
    libreoffice-writer \
    libreoffice-impress \
    libreoffice-draw

# Firefox and Thunderbird
sudo apt install -y firefox thunderbird

# Steam
if ! command -v steam &> /dev/null; then
    log "Installing Steam..."
    sudo apt install -y steam
fi

# =============================================================================
# 3. Install Flatpak applications
# =============================================================================

log "Installing Flatpak applications..."

# Ensure Flatpak is installed
sudo apt install -y flatpak

# Add Flathub repository
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak applications
FLATPAK_APPS=(
    "app.devsuite.Ptyxis"
    "com.bitwarden.desktop"
    "com.brave.Browser"
    "com.jgraph.drawio.desktop"
    "io.github.celluloid_player.Celluloid"
    "org.gimp.GIMP"
    "org.gnome.Loupe"
    "org.gnome.Mahjongg"
    "org.gnome.Papers"
    "org.localsend.localsend_app"
    "org.nickvision.tubeconverter"
    "org.qbittorrent.qBittorrent"
)

for app in "${FLATPAK_APPS[@]}"; do
    log "Installing Flatpak app: $app"
    sudo flatpak install -y flathub "$app" || warn "Failed to install $app"
done

# =============================================================================
# 4. Install Rust and Cargo tools
# =============================================================================

log "Setting up Rust environment..."
if ! command -v rustup &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
fi

# Install common Rust tools
cargo install cargo-clippy cargo-fmt || warn "Some Rust tools may already be installed"

# =============================================================================
# 5. Install .NET global tools
# =============================================================================

log "Installing .NET global tools..."
if command -v dotnet &> /dev/null; then
    dotnet tool install -g Microsoft.dotnet-interactive || warn ".NET interactive may already be installed"
fi

# =============================================================================
# 6. Configure shell environment
# =============================================================================

log "Configuring shell environment..."

# Backup existing files
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
fi

if [ -f ~/.bash_profile ]; then
    cp ~/.bash_profile ~/.bash_profile.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create .bash_profile with .NET tools path
cat > ~/.bash_profile << 'EOF'
# Add .NET Core SDK tools
export PATH="$PATH:/home/$USER/.dotnet/tools"
EOF

# Enhanced .bashrc configuration
cat >> ~/.bashrc << 'EOF'

# Custom environment variables
export GOOGLE_API_KEY="YOUR_GOOGLE_API_KEY_HERE"
export GEMINI_API_KEY="YOUR_GEMINI_API_KEY_HERE"

# Custom functions
function update-computer() {
    echo "Checking for system updates..."
    sudo apt-get update
    sudo apt-get upgrade -y
    echo "Checking for FlatPak updates..."
    flatpak upgrade -y
    echo "Checking for Snap updates..."
    sudo snap refresh
}

function gem() {
    echo "Launching Gemini..."
    cd ~/Documents/gemini
    gemini
}

# Rust environment
. "$HOME/.cargo/env"

# History with timestamps
export HISTTIMEFORMAT="%F %T "
EOF

# =============================================================================
# 7. Configure Git
# =============================================================================

log "Configuring Git..."
read -p "Enter your Git email: " git_email
read -p "Enter your Git name: " git_name

git config --global user.email "$git_email"
git config --global user.name "$git_name"

# =============================================================================
# 8. Install additional development tools
# =============================================================================

log "Installing additional development tools..."

# Warp Terminal (if available)
if [ ! -d "/opt/warpdotdev" ]; then
    log "Warp Terminal installation requires manual download from https://app.warp.dev/download"
fi

# Create common directories
mkdir -p ~/Documents/gemini
mkdir -p ~/Projects
mkdir -p ~/.local/share/applications

# =============================================================================
# 9. System tweaks and optimizations
# =============================================================================

log "Applying system tweaks..."

# Disable KVM modules to avoid VirtualBox conflicts
sudo tee /etc/modprobe.d/blacklist-kvm.conf > /dev/null << 'EOF'
blacklist kvm
blacklist kvm_intel
blacklist kvm_amd
EOF

sudo update-initramfs -u

# =============================================================================
# 10. Final setup and cleanup
# =============================================================================

log "Performing final setup..."

# Update package database
sudo apt update

# Clean up
sudo apt autoremove -y
sudo apt autoclean

# Source the new configuration
source ~/.bashrc

# =============================================================================
# Summary
# =============================================================================

log "Setup complete! Summary:"
echo "=================================="
echo "✓ System packages updated"
echo "✓ Development tools installed (Git, Rust, .NET, PowerShell, VS Code)"
echo "✓ Applications installed (LibreOffice, Firefox, Thunderbird, VirtualBox)"
echo "✓ Flatpak applications installed"
echo "✓ Shell environment configured"
echo "✓ Git configured"
echo "✓ System optimizations applied"
echo "=================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Update API keys in ~/.bashrc for Google/Gemini services"
echo "2. Install Warp Terminal manually if desired"
echo "3. VirtualBox should work without KVM conflicts"
echo "4. Reboot recommended to ensure all changes take effect"
echo ""
echo "Run 'source ~/.bashrc' to apply shell changes immediately"

log "Setup script completed successfully!"
