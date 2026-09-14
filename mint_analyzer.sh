#!/bin/bash

# =============================================================================
# Linux Mint System Analyzer and Setup Script Generator
# This script analyzes the current Linux Mint system and generates a setup script
# to replicate the configuration on another machine
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

OUTPUT_SCRIPT="mint_setup_$(date +%Y%m%d_%H%M%S).sh"
TEMP_DIR="/tmp/mint_system_analysis_$$"

log "Starting Linux Mint system analysis..."
log "Output script will be: $OUTPUT_SCRIPT"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# =============================================================================
# 1. Collect system information
# =============================================================================

log "Collecting system information..."

# OS Information
lsb_release -a > "$TEMP_DIR/os_info.txt" 2>/dev/null || echo "lsb_release not available" > "$TEMP_DIR/os_info.txt"
uname -a > "$TEMP_DIR/kernel_info.txt"

# Package information
log "Analyzing installed packages..."
dpkg --get-selections | grep -v deinstall | awk '{print $1}' > "$TEMP_DIR/apt_packages.txt"
apt list --manual-installed 2>/dev/null | grep -v "WARNING" | cut -d'/' -f1 | tail -n +2 > "$TEMP_DIR/manual_packages.txt"

# APT sources and PPAs
log "Collecting APT source configuration..."
mkdir -p "$TEMP_DIR/apt_sources"

cp /etc/apt/sources.list "$TEMP_DIR/apt_sources/sources.list" 2>/dev/null || touch "$TEMP_DIR/apt_sources/sources.list"
cp /etc/apt/sources.list.d/*.list "$TEMP_DIR/apt_sources/" 2>/dev/null || true
cp /etc/apt/sources.list.d/*.sources "$TEMP_DIR/apt_sources/" 2>/dev/null || true

{
    grep -hE '^[[:space:]]*deb([[:space:]]|\[)' /etc/apt/sources.list 2>/dev/null
    grep -hE '^[[:space:]]*deb([[:space:]]|\[)' /etc/apt/sources.list.d/*.list 2>/dev/null
    grep -hE '^[[:space:]]*URIs:[[:space:]]+' /etc/apt/sources.list.d/*.sources 2>/dev/null | sed -E 's/^[[:space:]]*URIs:[[:space:]]*/deb /'
} | sed 's/^[[:space:]]*//' > "$TEMP_DIR/apt_active_sources.txt" || touch "$TEMP_DIR/apt_active_sources.txt"

grep -Ei 'ppa\.launchpad(content)?\.net' "$TEMP_DIR/apt_active_sources.txt" > "$TEMP_DIR/ppa_sources.txt" || touch "$TEMP_DIR/ppa_sources.txt"

sed -nE 's#.*ppa\.launchpad(content)?\.net/([^/]+)/([^/]+).*#ppa:\2/\3#p' "$TEMP_DIR/ppa_sources.txt" | sort -u > "$TEMP_DIR/ppa_identifiers.txt" || touch "$TEMP_DIR/ppa_identifiers.txt"

grep -Eiv '(archive\.ubuntu\.com|security\.ubuntu\.com|packages\.linuxmint\.com|extra\.linuxmint\.com|ppa\.launchpad(content)?\.net)' "$TEMP_DIR/apt_active_sources.txt" > "$TEMP_DIR/custom_apt_sources.txt" || touch "$TEMP_DIR/custom_apt_sources.txt"

# Flatpak applications
log "Checking Flatpak applications..."
if command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application > "$TEMP_DIR/flatpak_apps.txt" 2>/dev/null || touch "$TEMP_DIR/flatpak_apps.txt"
else
    touch "$TEMP_DIR/flatpak_apps.txt"
fi

# Snap packages
log "Checking Snap packages..."
if command -v snap &> /dev/null; then
    snap list --unicode=never 2>/dev/null | tail -n +2 | awk '{print $1}' > "$TEMP_DIR/snap_packages.txt" || touch "$TEMP_DIR/snap_packages.txt"
else
    touch "$TEMP_DIR/snap_packages.txt"
fi

# Shell configuration
log "Analyzing shell configuration..."
cp ~/.bashrc "$TEMP_DIR/bashrc_backup" 2>/dev/null || touch "$TEMP_DIR/bashrc_backup"
cp ~/.bash_profile "$TEMP_DIR/bash_profile_backup" 2>/dev/null || touch "$TEMP_DIR/bash_profile_backup"
cp ~/.profile "$TEMP_DIR/profile_backup" 2>/dev/null || touch "$TEMP_DIR/profile_backup"

# Git configuration
if command -v git &> /dev/null; then
    log "Checking Git configuration..."
    git config --global user.name > "$TEMP_DIR/git_name.txt" 2>/dev/null || echo "" > "$TEMP_DIR/git_name.txt"
    git config --global user.email > "$TEMP_DIR/git_email.txt" 2>/dev/null || echo "" > "$TEMP_DIR/git_email.txt"
fi

# Development tools
log "Checking development tools..."
which code virtualbox pwsh docker rustc cargo npm node python3 java go > "$TEMP_DIR/dev_tools.txt" 2>/dev/null || touch "$TEMP_DIR/dev_tools.txt"

# Rust tools
if [ -d ~/.cargo/bin ]; then
    ls ~/.cargo/bin > "$TEMP_DIR/cargo_tools.txt"
else
    touch "$TEMP_DIR/cargo_tools.txt"
fi

# .NET tools
if [ -d ~/.dotnet/tools ]; then
    ls ~/.dotnet/tools > "$TEMP_DIR/dotnet_tools.txt"
else
    touch "$TEMP_DIR/dotnet_tools.txt"
fi

# Custom applications in /opt
find /opt -maxdepth 2 -type d 2>/dev/null | grep -v "^/opt$" > "$TEMP_DIR/opt_apps.txt" || touch "$TEMP_DIR/opt_apps.txt"

# User desktop entries
ls ~/.local/share/applications/*.desktop 2>/dev/null > "$TEMP_DIR/user_desktop_apps.txt" || touch "$TEMP_DIR/user_desktop_apps.txt"

# =============================================================================
# 2. Identify key packages and applications
# =============================================================================

log "Identifying key packages and applications..."

# Filter important packages
grep -E "(code|virtualbox|docker|rust|python|node|npm|git|vim|emacs|firefox|chrome|brave|vscode|jetbrains|idea|steam|discord|slack|zoom|obs|vlc|gimp|blender|libreoffice|thunderbird|evolution|mysql|postgresql|mongodb|redis|nginx|apache|php|java|openjdk|maven|gradle|go|golang|ruby|perl|lua|r-base|julia|scala|kotlin|swift|clang|gcc|make|cmake|curl|wget|ssh|rsync|tree|htop|neofetch|tmux|screen|zsh|fish|powershell|dotnet|mono|wine|virtualbox|qemu|kvm|vagrant|ansible|terraform|kubernetes|helm|minikube|docker-compose)" "$TEMP_DIR/manual_packages.txt" > "$TEMP_DIR/key_packages.txt" || touch "$TEMP_DIR/key_packages.txt"

# =============================================================================
# 3. Generate setup script
# =============================================================================

log "Generating setup script..."

cat > "$OUTPUT_SCRIPT" << 'SCRIPT_START'
#!/bin/bash

# =============================================================================
# System Setup Script
# Generated automatically by system_analyzer.sh
SCRIPT_START

echo "# Generated on: $(date)" >> "$OUTPUT_SCRIPT"
echo "# Source system: $(whoami)@$(hostname)" >> "$OUTPUT_SCRIPT"
echo "# OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")" >> "$OUTPUT_SCRIPT"

cat >> "$OUTPUT_SCRIPT" << 'SCRIPT_FUNCTIONS'
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

log "Starting system setup..."

# =============================================================================
# 1. Update system
# =============================================================================

log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# =============================================================================
# 2. Restore APT source configuration
# =============================================================================

log "Restoring APT source configuration..."
sudo mkdir -p /etc/apt/sources.list.d

if [ -f /etc/apt/sources.list ]; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)
fi

SCRIPT_FUNCTIONS

# Add APT sources section
if [ -d "$TEMP_DIR/apt_sources" ] && [ "$(find "$TEMP_DIR/apt_sources" -maxdepth 1 -type f | wc -l)" -gt 0 ]; then
    if [ -s "$TEMP_DIR/apt_sources/sources.list" ]; then
        echo "sudo tee /etc/apt/sources.list > /dev/null << 'EOF_APT_SOURCES_LIST'" >> "$OUTPUT_SCRIPT"
        cat "$TEMP_DIR/apt_sources/sources.list" >> "$OUTPUT_SCRIPT"
        echo "EOF_APT_SOURCES_LIST" >> "$OUTPUT_SCRIPT"
        echo "" >> "$OUTPUT_SCRIPT"
    fi

    for source_file in "$TEMP_DIR"/apt_sources/*.list "$TEMP_DIR"/apt_sources/*.sources; do
        [ -f "$source_file" ] || continue
        source_name=$(basename "$source_file")
        [ "$source_name" = "sources.list" ] && continue

        marker=$(echo "$source_name" | tr '.-' '__' | tr -cd '[:alnum:]_')

        echo "sudo tee /etc/apt/sources.list.d/$source_name > /dev/null << 'EOF_APT_${marker}'" >> "$OUTPUT_SCRIPT"
        cat "$source_file" >> "$OUTPUT_SCRIPT"
        echo "EOF_APT_${marker}" >> "$OUTPUT_SCRIPT"
        echo "" >> "$OUTPUT_SCRIPT"
    done

    echo "sudo apt update" >> "$OUTPUT_SCRIPT"
    echo "" >> "$OUTPUT_SCRIPT"
fi

cat >> "$OUTPUT_SCRIPT" << 'APT_INSTALL_SECTION'

# =============================================================================
# 3. Install key packages
# =============================================================================

log "Installing key packages..."
APT_INSTALL_SECTION

# Add key packages
if [ -s "$TEMP_DIR/key_packages.txt" ]; then
    echo "sudo apt install -y \\" >> "$OUTPUT_SCRIPT"
    while IFS= read -r package; do
        echo "    $package \\" >> "$OUTPUT_SCRIPT"
    done < "$TEMP_DIR/key_packages.txt"
    echo "" >> "$OUTPUT_SCRIPT"
fi

# Add Flatpak section
if [ -s "$TEMP_DIR/flatpak_apps.txt" ]; then
    cat >> "$OUTPUT_SCRIPT" << 'FLATPAK_SECTION'

# =============================================================================
# 3. Install Flatpak applications
# =============================================================================

log "Installing Flatpak applications..."
sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

FLATPAK_SECTION

    echo "FLATPAK_APPS=(" >> "$OUTPUT_SCRIPT"
    while IFS= read -r app; do
        echo "    \"$app\"" >> "$OUTPUT_SCRIPT"
    done < "$TEMP_DIR/flatpak_apps.txt"
    echo ")" >> "$OUTPUT_SCRIPT"

    cat >> "$OUTPUT_SCRIPT" << 'FLATPAK_INSTALL'

for app in "${FLATPAK_APPS[@]}"; do
    log "Installing Flatpak app: $app"
    sudo flatpak install -y flathub "$app" || warn "Failed to install $app"
done
FLATPAK_INSTALL
fi

# Add Snap section
if [ -s "$TEMP_DIR/snap_packages.txt" ]; then
    cat >> "$OUTPUT_SCRIPT" << 'SNAP_SECTION'

# =============================================================================
# 4. Install Snap packages
# =============================================================================

log "Installing Snap packages..."
sudo apt install -y snapd

SNAP_SECTION

    echo "SNAP_PACKAGES=(" >> "$OUTPUT_SCRIPT"
    while IFS= read -r package; do
        echo "    \"$package\"" >> "$OUTPUT_SCRIPT"
    done < "$TEMP_DIR/snap_packages.txt"
    echo ")" >> "$OUTPUT_SCRIPT"

    cat >> "$OUTPUT_SCRIPT" << 'SNAP_INSTALL'

for package in "${SNAP_PACKAGES[@]}"; do
    log "Installing Snap package: $package"
    sudo snap install "$package" || warn "Failed to install $package"
done
SNAP_INSTALL
fi

# Add shell configuration
cat >> "$OUTPUT_SCRIPT" << 'SHELL_CONFIG'

# =============================================================================
# 5. Configure shell environment
# =============================================================================

log "Configuring shell environment..."

# Backup existing files
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
fi

if [ -f ~/.bash_profile ]; then
    cp ~/.bash_profile ~/.bash_profile.backup.$(date +%Y%m%d_%H%M%S)
fi
SHELL_CONFIG

# Add .bash_profile content
if [ -s "$TEMP_DIR/bash_profile_backup" ]; then
    echo "" >> "$OUTPUT_SCRIPT"
    echo "# Create .bash_profile" >> "$OUTPUT_SCRIPT"
    echo "cat > ~/.bash_profile << 'EOF'" >> "$OUTPUT_SCRIPT"
    cat "$TEMP_DIR/bash_profile_backup" >> "$OUTPUT_SCRIPT"
    echo "EOF" >> "$OUTPUT_SCRIPT"
fi

# Add custom bashrc content (extract custom parts)
if [ -s "$TEMP_DIR/bashrc_backup" ]; then
    echo "" >> "$OUTPUT_SCRIPT"
    echo "# Add custom bashrc content" >> "$OUTPUT_SCRIPT"
    echo "cat >> ~/.bashrc << 'EOF'" >> "$OUTPUT_SCRIPT"
    
    # Extract custom functions and exports from bashrc
    grep -A 50 "# Custom\|function\|export.*API\|export.*KEY" "$TEMP_DIR/bashrc_backup" | head -50 >> "$OUTPUT_SCRIPT"
    
    echo "EOF" >> "$OUTPUT_SCRIPT"
fi

# Add Git configuration
if command -v git &> /dev/null; then
    GIT_NAME=$(cat "$TEMP_DIR/git_name.txt")
    GIT_EMAIL=$(cat "$TEMP_DIR/git_email.txt")
fi

if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    cat >> "$OUTPUT_SCRIPT" << GIT_CONFIG

# =============================================================================
# 6. Configure Git
# =============================================================================

log "Configuring Git..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
GIT_CONFIG
else
    cat >> "$OUTPUT_SCRIPT" << 'GIT_CONFIG_INTERACTIVE'

# =============================================================================
# 6. Configure Git
# =============================================================================

log "Configuring Git..."
read -p "Enter your Git email: " git_email
read -p "Enter your Git name: " git_name

git config --global user.email "$git_email"
git config --global user.name "$git_name"
GIT_CONFIG_INTERACTIVE
fi

# Add development tools setup
if [ -s "$TEMP_DIR/cargo_tools.txt" ] || [ -s "$TEMP_DIR/dotnet_tools.txt" ]; then
    cat >> "$OUTPUT_SCRIPT" << 'DEV_TOOLS'

# =============================================================================
# 7. Install development tools
# =============================================================================
DEV_TOOLS

    # Rust tools
    if [ -s "$TEMP_DIR/cargo_tools.txt" ]; then
        cat >> "$OUTPUT_SCRIPT" << 'RUST_TOOLS'

log "Setting up Rust environment..."
if ! command -v rustup &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
fi
RUST_TOOLS
    fi

    # .NET tools
    if [ -s "$TEMP_DIR/dotnet_tools.txt" ]; then
        cat >> "$OUTPUT_SCRIPT" << 'DOTNET_TOOLS'

log "Installing .NET global tools..."
if command -v dotnet &> /dev/null; then
DOTNET_TOOLS
        while IFS= read -r tool; do
            echo "    dotnet tool install -g $tool || warn \"$tool may already be installed\"" >> "$OUTPUT_SCRIPT"
        done < "$TEMP_DIR/dotnet_tools.txt"
        echo "fi" >> "$OUTPUT_SCRIPT"
    fi
fi

# Add system tweaks
cat >> "$OUTPUT_SCRIPT" << 'SYSTEM_TWEAKS'

# =============================================================================
# 8. System tweaks and optimizations
# =============================================================================

log "Applying system tweaks..."

# Create common directories
mkdir -p ~/Documents
mkdir -p ~/Projects
mkdir -p ~/.local/share/applications

# VirtualBox KVM conflict fix (if VirtualBox is installed)
if command -v virtualbox &> /dev/null; then
    sudo tee /etc/modprobe.d/blacklist-kvm.conf > /dev/null << 'EOF'
blacklist kvm
blacklist kvm_intel
blacklist kvm_amd
EOF
    sudo update-initramfs -u
fi

# =============================================================================
# 9. Final setup and cleanup
# =============================================================================

log "Performing final setup..."

# Update package database
sudo apt update

# Clean up
sudo apt autoremove -y
sudo apt autoclean

# Source the new configuration
source ~/.bashrc 2>/dev/null || true

# =============================================================================
# Summary
# =============================================================================

log "Setup complete! Summary:"
echo "=================================="
echo "✓ System packages updated"
echo "✓ Key applications installed"
echo "✓ Shell environment configured"
echo "✓ Git configured"
echo "✓ Development tools installed"
echo "✓ System optimizations applied"
echo "=================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Review and update any API keys in ~/.bashrc"
echo "2. Reboot recommended to ensure all changes take effect"
echo "3. Run 'source ~/.bashrc' to apply shell changes immediately"
echo ""

log "Setup script completed successfully!"
SYSTEM_TWEAKS

# Make the generated script executable
chmod +x "$OUTPUT_SCRIPT"

# =============================================================================
# 4. Generate summary report
# =============================================================================

log "Generating analysis report..."

cat > "system_analysis_report.txt" << REPORT_START
System Analysis Report
Generated: $(date)
Source: $(whoami)@$(hostname)
OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")

================================
PACKAGE SUMMARY
================================
Total APT packages: $(wc -l < "$TEMP_DIR/apt_packages.txt")
Manual APT packages: $(wc -l < "$TEMP_DIR/manual_packages.txt")
Key packages: $(wc -l < "$TEMP_DIR/key_packages.txt")
Flatpak apps: $(wc -l < "$TEMP_DIR/flatpak_apps.txt")
Snap packages: $(wc -l < "$TEMP_DIR/snap_packages.txt")
PPA sources: $(wc -l < "$TEMP_DIR/ppa_identifiers.txt")
Custom APT sources: $(wc -l < "$TEMP_DIR/custom_apt_sources.txt")

================================
KEY PACKAGES
================================
REPORT_START

if [ -s "$TEMP_DIR/key_packages.txt" ]; then
    cat "$TEMP_DIR/key_packages.txt" >> "system_analysis_report.txt"
fi

echo "" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"
echo "PPA CONFIGURATIONS" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"

if [ -s "$TEMP_DIR/ppa_identifiers.txt" ]; then
    cat "$TEMP_DIR/ppa_identifiers.txt" >> "system_analysis_report.txt"
fi

echo "" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"
echo "CUSTOM APT SOURCES" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"

if [ -s "$TEMP_DIR/custom_apt_sources.txt" ]; then
    cat "$TEMP_DIR/custom_apt_sources.txt" >> "system_analysis_report.txt"
fi

echo "" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"
echo "FLATPAK APPLICATIONS" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"

if [ -s "$TEMP_DIR/flatpak_apps.txt" ]; then
    cat "$TEMP_DIR/flatpak_apps.txt" >> "system_analysis_report.txt"
fi

echo "" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"
echo "DEVELOPMENT TOOLS" >> "system_analysis_report.txt"
echo "================================" >> "system_analysis_report.txt"

if [ -s "$TEMP_DIR/dev_tools.txt" ]; then
    cat "$TEMP_DIR/dev_tools.txt" >> "system_analysis_report.txt"
fi

if [ -s "$TEMP_DIR/cargo_tools.txt" ]; then
    echo "" >> "system_analysis_report.txt"
    echo "Rust/Cargo tools:" >> "system_analysis_report.txt"
    cat "$TEMP_DIR/cargo_tools.txt" >> "system_analysis_report.txt"
fi

if [ -s "$TEMP_DIR/dotnet_tools.txt" ]; then
    echo "" >> "system_analysis_report.txt"
    echo ".NET tools:" >> "system_analysis_report.txt"
    cat "$TEMP_DIR/dotnet_tools.txt" >> "system_analysis_report.txt"
fi

# =============================================================================
# 5. Final output
# =============================================================================

log "Analysis complete!"
echo "=================================="
echo "Generated files:"
echo "✓ Setup script: $OUTPUT_SCRIPT"
echo "✓ Analysis report: system_analysis_report.txt"
echo "=================================="
echo ""
echo "To replicate this system on another machine:"
echo "1. Copy $OUTPUT_SCRIPT to the target machine"
echo "2. Make it executable: chmod +x $OUTPUT_SCRIPT"
echo "3. Run it: ./$OUTPUT_SCRIPT"
echo ""
echo "The setup script includes:"
echo "• $(wc -l < "$TEMP_DIR/key_packages.txt" 2>/dev/null || echo 0) key APT packages"
echo "• $(wc -l < "$TEMP_DIR/flatpak_apps.txt" 2>/dev/null || echo 0) Flatpak applications"
echo "• $(wc -l < "$TEMP_DIR/snap_packages.txt" 2>/dev/null || echo 0) Snap packages"
echo "• $(wc -l < "$TEMP_DIR/ppa_identifiers.txt" 2>/dev/null || echo 0) PPA configurations"
echo "• $(wc -l < "$TEMP_DIR/custom_apt_sources.txt" 2>/dev/null || echo 0) Custom APT sources"
echo "• $(wc -l < "$TEMP_DIR/dev_tools.txt" 2>/dev/null || echo 0) Development tools"
echo "• $(wc -l < "$TEMP_DIR/cargo_tools.txt" 2>/dev/null || echo 0) Rust/Cargo tools"
echo "• $(wc -l < "$TEMP_DIR/dotnet_tools.txt" 2>/dev/null || echo 0) .NET tools"
echo "• Shell configuration and customizations"
echo "• Git configuration"
echo "• Development tools setup"
echo "• System optimizations"

log "System analysis completed successfully!"

# Clean up temporary directory
rm -rf "$TEMP_DIR"