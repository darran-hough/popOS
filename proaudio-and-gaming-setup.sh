#!/bin/bash
# ============================================================
#  Pro Audio + Gaming Setup Script (ULTIMATE EDITION)
#  Target: Pop!_OS 24.04 LTS | AMD CPU | NVIDIA RTX 5060
#  Audio Interface: Focusrite Scarlett 8i6
#  Gaming: Full peripheral support, controller auto-detect, ProtonPlus
#  
#  NEW FEATURES:
#   - Logitech device support (Piper)
#   - Razer device support (OpenRazer + Polychromatic)
#   - Auto-detect Xbox/PS4/PS5/Nintendo controllers
#   - ProtonPlus for easy Proton-GE management
#   - MangoHud + GOverlay for performance monitoring
#   - Lutris game manager
#   - CoreCtrl for AMD GPU/CPU control
#   - Enhanced gaming kernel parameters
#   - Hardware auto-detection
# ============================================================
#
# Run with:
#   chmod +x proaudio-gaming-ultimate.sh && ./proaudio-gaming-ultimate.sh
#
# IMPORTANT: Run as your normal user (NOT as root/sudo).
#            The script will call sudo when needed.
#
# What this script does:
#   1.  System update
#   2.  Hardware auto-detection
#   3.  Focusrite Scarlett 8i6 driver setup
#   4.  PipeWire low-latency tuning
#   5.  Real-time audio limits
#   6.  Kernel parameters (gaming + audio optimized)
#   7.  sysctl tweaks (gaming + audio)
#   8.  NVIDIA driver + gaming dependencies
#   9.  Wine Staging
#  10.  Winetricks + Windows runtimes
#  11.  Yabridge (VST bridge)
#  12.  Steam + Proton configuration
#  13.  Heroic Games Launcher
#  14.  ProtonPlus (Proton-GE manager)
#  15.  Lutris
#  16.  Logitech peripheral support (Piper)
#  17.  Razer peripheral support (OpenRazer)
#  18.  Controller support (Xbox/PS/Nintendo)
#  19.  MangoHud + GOverlay
#  20.  CoreCtrl (AMD control)
#  21.  Pro audio tools
#  22.  Gaming optimizations
# ============================================================

set -e

# ---- Colours -----------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

notify() {
  echo ""
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${GREEN}  $1${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""
}

warn() {
  echo -e "${YELLOW}  [WARN] $1${NC}"
}

info() {
  echo -e "${BLUE}  [INFO] $1${NC}"
}

# ---- Safety check ------------------------------------------
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Do NOT run this script as root. Run as your normal user.${NC}"
  exit 1
fi

# ============================================================
# 1. SYSTEM UPDATE
# ============================================================
notify "1/22 — Updating system packages"
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y


# ============================================================
# 2. HARDWARE AUTO-DETECTION
# ============================================================
notify "2/22 — Detecting hardware"

info "Detecting CPU..."
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
echo "  CPU: $CPU_MODEL ($CPU_VENDOR)"

info "Detecting GPU..."
if lspci | grep -i "VGA.*NVIDIA" > /dev/null; then
  GPU_NVIDIA=true
  GPU_MODEL=$(lspci | grep -i "VGA.*NVIDIA" | cut -d: -f3 | xargs)
  echo "  GPU: $GPU_MODEL (NVIDIA detected)"
else
  GPU_NVIDIA=false
  echo "  GPU: No NVIDIA GPU detected"
fi

if lspci | grep -i "VGA.*AMD\|VGA.*ATI" > /dev/null; then
  GPU_AMD=true
  GPU_AMD_MODEL=$(lspci | grep -i "VGA.*AMD\|VGA.*ATI" | cut -d: -f3 | xargs)
  echo "  GPU: $GPU_AMD_MODEL (AMD detected)"
else
  GPU_AMD=false
fi

info "Detecting audio interfaces..."
if lsusb | grep -i "focusrite" > /dev/null; then
  SCARLETT_DETECTED=true
  SCARLETT_INFO=$(lsusb | grep -i "focusrite")
  echo "  Audio: Focusrite device detected"
  echo "  $SCARLETT_INFO"
else
  SCARLETT_DETECTED=false
  warn "No Focusrite device detected - Scarlett setup will be skipped"
fi

info "Detecting gaming peripherals..."
LOGITECH_DETECTED=false
RAZER_DETECTED=false

if lsusb | grep -i "logitech" > /dev/null; then
  LOGITECH_DETECTED=true
  echo "  ✓ Logitech devices detected"
fi

if lsusb | grep -i "razer" > /dev/null; then
  RAZER_DETECTED=true
  echo "  ✓ Razer devices detected"
fi

info "Detecting controllers..."
XBOX_DETECTED=false
PS4_DETECTED=false
PS5_DETECTED=false
NINTENDO_DETECTED=false

if lsusb | grep -iE "Xbox|045e:(0.*2[de]|0.*b[012])" > /dev/null; then
  XBOX_DETECTED=true
  echo "  ✓ Xbox controller detected"
fi

if lsusb | grep -iE "Sony.*Wireless Controller|054c:0.*9cc" > /dev/null; then
  PS4_DETECTED=true
  echo "  ✓ PS4 controller detected"
fi

if lsusb | grep -iE "DualSense|054c:0.*ce6" > /dev/null; then
  PS5_DETECTED=true
  echo "  ✓ PS5 controller detected"
fi

if lsusb | grep -iE "Nintendo|057e:" > /dev/null; then
  NINTENDO_DETECTED=true
  echo "  ✓ Nintendo controller detected"
fi

echo ""
sleep 2


# ============================================================
# 3. FOCUSRITE SCARLETT 8i6 — snd_usb_audio driver setup
# ============================================================
if [ "$SCARLETT_DETECTED" = true ]; then
  notify "3/22 — Configuring Focusrite Scarlett 8i6"

  sudo tee /etc/modprobe.d/scarlett.conf > /dev/null <<'EOF'
# Focusrite Scarlett 8i6 — enable full mixer/routing support
# vid=0x1235 is Focusrite, pid=0x8213 is the 8i6
options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1
EOF

  echo "  Scarlett 8i6 module config written to /etc/modprobe.d/scarlett.conf"

  sudo apt install -y alsa-scarlett-gui 2>/dev/null || \
    warn "alsa-scarlett-gui not found in repos — you can build it from: https://github.com/geoffreybennett/alsa-scarlett-gui"

  sudo update-initramfs -u
else
  notify "3/22 — Skipping Scarlett setup (no device detected)"
fi


# ============================================================
# 4. PIPEWIRE LOW-LATENCY TUNING
# ============================================================
notify "4/22 — Tuning PipeWire for low-latency pro audio"

sudo apt install -y pipewire-jack pipewire-alsa libspa-0.2-jack

mkdir -p ~/.config/wireplumber/wireplumber.conf.d

cat > ~/.config/wireplumber/wireplumber.conf.d/50-pro-audio.conf <<'EOF'
# Pro audio tuning drop-in for Pop!_OS 24.04
# Safe to delete to revert: rm ~/.config/wireplumber/wireplumber.conf.d/50-pro-audio.conf
#
# Quantum guide (adjust to taste):
#   64  = ~1.3ms  (very low latency, demanding on CPU)
#   128 = ~2.7ms  (recommended starting point)
#   256 = ~5.3ms  (safer for plugin-heavy sessions)

monitor.alsa.rules = [
  {
    matches = [ { node.name = "~alsa_output.*" } ]
    actions = {
      update-props = {
        audio.rate          = 48000
        audio.allowed-rates = "44100,48000,88200,96000"
      }
    }
  }
]
EOF

echo "  WirePlumber drop-in written to ~/.config/wireplumber/wireplumber.conf.d/50-pro-audio.conf"
echo ""
echo "  To change quantum at runtime (no reboot, takes effect immediately):"
echo "    pw-metadata -n settings 0 clock.force-quantum 128"
echo "  To revert to default quantum:"
echo "    pw-metadata -n settings 0 clock.force-quantum 0"

systemctl --user restart wireplumber pipewire-pulse 2>/dev/null || true


# ============================================================
# 5. REAL-TIME AUDIO LIMITS
# ============================================================
notify "5/22 — Setting real-time audio limits"

sudo tee /etc/security/limits.d/audio.conf > /dev/null <<'EOF'
# Real-time audio — required for DAWs and low-latency audio
@audio - rtprio  90
@audio - memlock unlimited
@audio - nice    -19
EOF

sudo usermod -aG audio "$USER"
echo "  User '$USER' added to audio group (takes effect after logout/login)"


# ============================================================
# 6. KERNEL PARAMETERS via kernelstub (GAMING + AUDIO OPTIMIZED)
# ============================================================
notify "6/22 — Applying kernel parameters via kernelstub"

# Remove any existing conflicting parameters first
sudo kernelstub -d "mitigations=auto" 2>/dev/null || true
sudo kernelstub -d "split_lock_detect=fatal" 2>/dev/null || true

# Gaming + Audio optimized kernel parameters
sudo kernelstub -a "threadirqs"                              # Move IRQs to threads for lower latency
sudo kernelstub -a "mitigations=off"                         # Disable CPU mitigations for max performance
sudo kernelstub -a "split_lock_detect=off"                   # Disable split lock detection (gaming performance)
sudo kernelstub -a "cpufreq.default_governor=performance"    # Keep CPU at max frequency
sudo kernelstub -a "amd_pstate=active"                       # AMD P-state driver for better frequency control
sudo kernelstub -a "transparent_hugepage=always"             # Better memory performance for games
sudo kernelstub -a "amdgpu.ppfeaturemask=0xffffffff" 2>/dev/null || true  # Enable all AMD GPU features

echo ""
echo "  Current kernel options:"
sudo kernelstub -p 2>/dev/null | grep "Kernel Boot Options" || true
warn "Kernel params take effect after reboot"


# ============================================================
# 7. SYSCTL TWEAKS (GAMING + AUDIO OPTIMIZED)
# ============================================================
notify "7/22 — Applying sysctl tweaks (gaming + audio)"

sudo tee /etc/sysctl.d/99-proaudio-gaming.conf > /dev/null <<'EOF'
# Pro Audio + Gaming sysctl tweaks — Pop!_OS 24.04
# Safe to delete this file to revert all changes.

# Reduce swap usage — keeps audio buffers and game data in RAM
vm.swappiness=10

# More inotify watches — DAWs, plugin managers, and Steam need this
fs.inotify.max_user_watches=600000

# Increased memory map areas — required for many games (especially Source 2 games)
# Default is 65530, many games need 1048576
vm.max_map_count=1048576

# File handle limits — helps with large game libraries
fs.file-max=2097152

# Network optimizations for online gaming
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=1048576
net.core.wmem_default=1048576
net.ipv4.tcp_rmem=4096 1048576 16777216
net.ipv4.tcp_wmem=4096 1048576 16777216
net.core.netdev_max_backlog=5000

# Reduce network latency
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_timestamps=0
EOF

echo "  sysctl drop-in written to /etc/sysctl.d/99-proaudio-gaming.conf"
sudo sysctl --system > /dev/null
echo "  sysctl settings applied (also active after every reboot automatically)"


# ============================================================
# 8. NVIDIA RTX 5060 DRIVERS & GAMING DEPENDENCIES
# ============================================================
notify "8/22 — NVIDIA drivers and gaming dependencies"

if [ "$GPU_NVIDIA" = true ]; then
  sudo apt install -y \
    system76-driver-nvidia \
    nvidia-utils-570 \
    libnvidia-gl-570 \
    libnvidia-gl-570:i386 2>/dev/null || \
    warn "Some NVIDIA packages not found — Pop!_OS may already have the right driver"
  
  # NVIDIA power management settings
  sudo tee /etc/modprobe.d/nvidia-power.conf > /dev/null <<'EOF'
# NVIDIA power management — prefer maximum performance for gaming
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
  sudo update-initramfs -u
  
  info "NVIDIA driver configured"
else
  info "Skipping NVIDIA driver installation (no NVIDIA GPU detected)"
fi

# Vulkan + 32-bit support (needed for all GPUs)
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y \
  vulkan-tools \
  libvulkan1 \
  libvulkan1:i386 \
  mesa-vulkan-drivers \
  mesa-vulkan-drivers:i386

# GameMode — lets games request high-performance mode
sudo apt install -y gamemode lib32-gamemode 2>/dev/null || sudo apt install -y gamemode

echo "  GameMode installed"
echo "  To use GameMode with a game: gamemoderun %command% (in Steam launch options)"


# ============================================================
# 9. WINE (STANDARD)
# ============================================================
notify "9/22 — Installing Wine"

sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y wine wine64 wine32 winbind libntlm0

echo "  Wine installed: $(wine --version 2>/dev/null || echo 'check manually')"

# Wine desktop integration
mkdir -p ~/.local/share/applications

cat > ~/.local/share/applications/wine.desktop <<'EOF'
[Desktop Entry]
Name=Wine Windows Program Loader
Exec=wine %f
Type=Application
MimeType=application/x-ms-dos-executable;application/x-msdownload;
Icon=wine
NoDisplay=false
StartupNotify=true
EOF

cat > ~/.local/share/applications/wine-msi.desktop <<'MSIEOF'
[Desktop Entry]
Name=Wine MSI Installer
Exec=wine msiexec /i %f /quiet /norestart
Type=Application
MimeType=application/x-msi;
Icon=wine
NoDisplay=false
StartupNotify=true
MSIEOF

xdg-mime default wine.desktop application/x-ms-dos-executable
xdg-mime default wine.desktop application/x-msdownload
xdg-mime default wine-msi.desktop application/x-msi
update-desktop-database ~/.local/share/applications

echo "  Wine registered as default handler for .exe and .msi files"


# ============================================================
# 10. WINETRICKS + WINDOWS RUNTIME DEPENDENCIES
# ============================================================
notify "10/22 — Installing Winetricks and Windows runtime dependencies"

sudo apt install -y cabextract
mkdir -p ~/.local/share/winetricks

wget -O ~/.local/share/winetricks/winetricks \
  https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x ~/.local/share/winetricks/winetricks

if ! grep -q "winetricks" ~/.bash_aliases 2>/dev/null; then
  {
    echo ""
    echo "# Winetricks"
    echo 'export PATH="$PATH:$HOME/.local/share/winetricks"'
  } >> ~/.bash_aliases
fi

. ~/.bash_aliases 2>/dev/null || true

# Set Wine to Windows 10 mode
winecfg /v win10

# Core fonts
~/.local/share/winetricks/winetricks -q corefonts || \
  warn "winetricks corefonts failed — run manually: winetricks corefonts"

# Visual C++ runtimes
~/.local/share/winetricks/winetricks -q \
  vcrun2013 \
  vcrun2015 \
  vcrun2019 \
  vcrun2022 || true

# Additional runtimes
~/.local/share/winetricks/winetricks -q \
  gdiplus \
  mfc42 \
  mfc140 \
  urlmon \
  wininet \
  dxvk || true

# .NET runtimes
wineserver -k 2>/dev/null || true
sleep 2
~/.local/share/winetricks/winetricks -q dotnet35 || true
wineserver -k 2>/dev/null || true
sleep 2
~/.local/share/winetricks/winetricks -q dotnet48 || true
wineserver -k 2>/dev/null || true

# Create missing Downloads folders
mkdir -p "$HOME/.wine/drive_c/users/Public/Downloads"
mkdir -p "$HOME/.wine/drive_c/users/$USER/Downloads"
echo "  Created Wine user Downloads folders"

# Save clean Wine prefix
if [ ! -d ~/.wine-base ]; then
  cp -r ~/.wine ~/.wine-base
  echo "  Saved clean Wine prefix to ~/.wine-base"
fi

# Native Instruments helper
mkdir -p ~/.local/bin
cat > ~/.local/bin/native-access << 'NAEOF'
#!/bin/bash
NTKDAEMON="$HOME/.wine/drive_c/Program Files/Native Instruments/NTKDaemon/NTKDaemon.exe"
NATIVE_ACCESS="$HOME/.wine/drive_c/Program Files/Native Instruments/Native Access/Native Access.exe"
NA_INSTALLER="$HOME/.cache/native-access/NativeAccess_Setup.exe"
NA_DOWNLOAD_URL="https://downloads.native-instruments.com/releases/nativeaccess/NativeAccess_Setup.exe"

if [ -f "$NATIVE_ACCESS" ]; then
  echo "Starting NTKDaemon..."
  wine "$NTKDAEMON" &
  sleep 4
  echo "Launching Native Access 2..."
  wine "$NATIVE_ACCESS"
  exit 0
fi

echo "Native Access 2 is not installed yet."
echo ""

if [ ! -f "$NA_INSTALLER" ] || [ ! -s "$NA_INSTALLER" ]; then
  echo "Downloading Native Access 2 installer..."
  mkdir -p "$HOME/.cache/native-access"
  wget -q --show-progress "$NA_DOWNLOAD_URL" -O "$NA_INSTALLER"

  if [ ! -f "$NA_INSTALLER" ] || [ ! -s "$NA_INSTALLER" ]; then
    echo ""
    echo "  Auto-download failed — NI may have updated their download URL."
    echo "  Download Native Access manually from:"
    echo "  https://www.native-instruments.com/en/specials/free-downloads/native-access/"
    echo "  Save the installer to: $NA_INSTALLER"
    echo "  Then run: native-access"
    rm -f "$NA_INSTALLER"
    exit 1
  fi
else
  echo "Found cached installer at $NA_INSTALLER"
fi

echo ""
echo "Running installer — follow the prompts in the Wine window..."
wine "$NA_INSTALLER"

if [ -f "$NATIVE_ACCESS" ]; then
  echo ""
  echo "Installation complete — launching Native Access 2..."
  wine "$NTKDAEMON" &
  sleep 4
  wine "$NATIVE_ACCESS"
else
  echo ""
  echo "Native Access does not appear to be installed yet."
  echo "If the installer is still running, wait for it to finish then run: native-access"
fi
NAEOF

chmod +x ~/.local/bin/native-access

if ! grep -q 'HOME/.local/bin' ~/.bash_aliases 2>/dev/null; then
  echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bash_aliases
fi

echo ""
echo "  Native Access 2 helper saved to ~/.local/bin/native-access"


# ============================================================
# 11. YABRIDGE 5.1.0 — Windows VST2/VST3/CLAP bridge
# ============================================================
notify "11/22 — Installing Yabridge 5.1.0"

YABRIDGE_VERSION="5.1.0"
YABRIDGE_URL="https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/yabridge-${YABRIDGE_VERSION}.tar.gz"

wget -O /tmp/yabridge.tar.gz "$YABRIDGE_URL"
mkdir -p ~/.local/share
tar -C ~/.local/share -xavf /tmp/yabridge.tar.gz
rm /tmp/yabridge.tar.gz

if ! grep -q "yabridge" ~/.bash_aliases 2>/dev/null; then
  {
    echo ""
    echo "# Yabridge — Windows VST bridge"
    echo 'export PATH="$PATH:$HOME/.local/share/yabridge"'
  } >> ~/.bash_aliases
fi

. ~/.bash_aliases 2>/dev/null || true

sudo apt install -y libnotify-bin

mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/CLAP"

~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Common Files/CLAP"

~/.local/share/yabridge/yabridgectl sync

echo "  After installing Windows VST plugins via Wine, run: yabridgectl sync"


# ============================================================
# 12. STEAM + PROTON CONFIGURATION
# ============================================================
notify "12/22 — Installing Steam and configuring Proton"

sudo apt install -y steam-installer

# Create Steam config directory
mkdir -p ~/.steam/steam

# Enable beta participation for latest features (optional)
info "Configuring Steam for optimal gaming..."

# Create udev rules for Steam controller support
sudo tee /etc/udev/rules.d/70-steam-controller.rules > /dev/null <<'EOF'
# Steam Controller udev rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "  Steam installed and configured"
echo "  IMPORTANT: Enable Steam Play in Steam settings:"
echo "  Steam > Settings > Compatibility > Enable Steam Play for all other titles"
echo "  Select latest Proton version for best compatibility"


# ============================================================
# 13. HEROIC GAMES LAUNCHER
# ============================================================
notify "13/22 — Installing Heroic Games Launcher"

if command -v flatpak &> /dev/null; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub com.heroicgameslauncher.hgl || \
    warn "Heroic Flatpak install failed — try manually from Software Centre"
  echo "  Heroic installed via Flatpak"
else
  warn "Flatpak not found — installing it first"
  sudo apt install -y flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub com.heroicgameslauncher.hgl || \
    warn "Heroic install failed — try manually from Software Centre"
fi


# ============================================================
# 14. PROTONPLUS — Easy Proton-GE Management
# ============================================================
notify "14/22 — Installing ProtonPlus (Proton-GE manager)"

# ProtonPlus is the easiest way to install and manage Proton-GE versions
# It provides a simple GUI for downloading and switching between Proton-GE releases

if command -v flatpak &> /dev/null; then
  flatpak install -y flathub com.vysp3r.ProtonPlus || \
    warn "ProtonPlus install failed — try manually: flatpak install flathub com.vysp3r.ProtonPlus"
  echo "  ProtonPlus installed via Flatpak"
  echo "  Launch with: flatpak run com.vysp3r.ProtonPlus"
else
  # Alternative: Install ProtonPlus AppImage
  info "Installing ProtonPlus AppImage..."
  mkdir -p ~/Applications
  
  # Get latest ProtonPlus release
  PROTONPLUS_URL=$(curl -s https://api.github.com/repos/Vysp3r/ProtonPlus/releases/latest | grep "browser_download_url.*AppImage" | cut -d '"' -f 4)
  
  if [ -n "$PROTONPLUS_URL" ]; then
    wget -O ~/Applications/ProtonPlus.AppImage "$PROTONPLUS_URL"
    chmod +x ~/Applications/ProtonPlus.AppImage
    
    # Create desktop entry
    cat > ~/.local/share/applications/protonplus.desktop <<'PPEOF'
[Desktop Entry]
Name=ProtonPlus
Exec=$HOME/Applications/ProtonPlus.AppImage
Type=Application
Icon=protonplus
Categories=Game;Utility;
Terminal=false
PPEOF
    
    update-desktop-database ~/.local/share/applications
    echo "  ProtonPlus installed to ~/Applications/ProtonPlus.AppImage"
  else
    warn "Could not download ProtonPlus — install manually from: https://github.com/Vysp3r/ProtonPlus"
  fi
fi


# ============================================================
# 15. LUTRIS — Universal Game Manager
# ============================================================
notify "15/22 — Installing Lutris"

sudo add-apt-repository -y ppa:lutris-team/lutris 2>/dev/null || true
sudo apt update
sudo apt install -y lutris

echo "  Lutris installed"
echo "  Lutris supports: GOG, EA, Ubisoft, Blizzard, and more"


# ============================================================
# 16. LOGITECH PERIPHERAL SUPPORT (Piper)
# ============================================================
notify "16/22 — Installing Logitech peripheral support (Piper)"

if [ "$LOGITECH_DETECTED" = true ]; then
  info "Logitech devices detected — installing Piper"
  
  sudo apt install -y piper
  
  # Enable and start ratbagd service (required for Piper)
  sudo systemctl enable --now ratbagd
  
  echo "  Piper installed"
  echo "  Launch Piper to configure your Logitech devices"
  echo "  Supported: Logitech G-series mice and keyboards"
else
  info "No Logitech devices detected — skipping Piper installation"
  echo "  If you connect Logitech devices later, install with: sudo apt install piper"
fi


# ============================================================
# 17. RAZER PERIPHERAL SUPPORT (OpenRazer + Polychromatic)
# ============================================================
notify "17/22 — Installing Razer peripheral support (OpenRazer)"

if [ "$RAZER_DETECTED" = true ]; then
  info "Razer devices detected — installing OpenRazer + Polychromatic"
  
  # Add OpenRazer repository
  sudo add-apt-repository -y ppa:openrazer/stable 2>/dev/null || true
  sudo apt update
  
  # Install OpenRazer daemon and Python library
  sudo apt install -y openrazer-meta
  
  # Add user to plugdev group (required for OpenRazer)
  sudo usermod -aG plugdev "$USER"
  
  # Install Polychromatic (GUI for OpenRazer)
  sudo apt install -y polychromatic
  
  echo "  OpenRazer + Polychromatic installed"
  echo "  Launch Polychromatic to configure your Razer devices"
  echo "  Log out and back in for group changes to take effect"
else
  info "No Razer devices detected — skipping OpenRazer installation"
  echo "  If you connect Razer devices later, install with: sudo apt install openrazer-meta polychromatic"
fi


# ============================================================
# 18. CONTROLLER SUPPORT (Xbox/PlayStation/Nintendo)
# ============================================================
notify "18/22 — Installing controller support"

# xpadneo — Modern Xbox controller driver (Xbox One/Series X|S)
if [ "$XBOX_DETECTED" = true ]; then
  info "Xbox controller detected — installing xpadneo driver"
  
  sudo apt install -y dkms linux-headers-generic
  
  # Clone and install xpadneo
  if [ ! -d /tmp/xpadneo ]; then
    git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo
    cd /tmp/xpadneo
    sudo ./install.sh
    cd -
  fi
  
  echo "  xpadneo installed (Xbox wireless controller support)"
else
  info "No Xbox controller detected — xpadneo installation skipped"
fi

# DualShock 4 support (built into kernel, but we add userspace tools)
if [ "$PS4_DETECTED" = true ]; then
  info "PS4 controller detected — installing ds4drv"
  
  sudo apt install -y python3-pip
  sudo pip3 install ds4drv --break-system-packages
  
  # Create systemd service for ds4drv
  mkdir -p ~/.config/systemd/user
  cat > ~/.config/systemd/user/ds4drv.service <<'DS4EOF'
[Unit]
Description=DS4 Driver
After=bluetooth.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ds4drv --hidraw
Restart=on-failure

[Install]
WantedBy=default.target
DS4EOF
  
  systemctl --user enable ds4drv 2>/dev/null || true
  
  echo "  ds4drv installed (PS4 controller support)"
  echo "  Start with: systemctl --user start ds4drv"
fi

# DualSense (PS5) support
if [ "$PS5_DETECTED" = true ]; then
  info "PS5 controller detected — installing dualsensectl"
  
  # DualSense support is built into Linux 5.12+, but dualsensectl adds extra features
  if ! command -v dualsensectl &> /dev/null; then
    # Install from source
    sudo apt install -y build-essential pkg-config libdbus-1-dev libhidapi-dev
    
    if [ ! -d /tmp/dualsensectl ]; then
      git clone https://github.com/nowrep/dualsensectl.git /tmp/dualsensectl
      cd /tmp/dualsensectl
      make
      sudo make install
      cd -
    fi
  fi
  
  echo "  dualsensectl installed (PS5 DualSense support)"
  echo "  Control LED, rumble, etc. with: dualsensectl"
fi

# Nintendo controller support (kernel built-in, just verify)
if [ "$NINTENDO_DETECTED" = true ]; then
  info "Nintendo controller detected — kernel support is built-in"
  echo "  Nintendo Pro Controller/Joy-Cons supported natively"
  echo "  Use in Steam: Enable Nintendo Pro Controller in Steam settings"
fi

# Generic controller support
sudo apt install -y joystick jstest-gtk

echo ""
echo "  Test controllers with: jstest /dev/input/js0"
echo "  GUI testing tool: jstest-gtk"


# ============================================================
# 19. MANGOHUD + GOVERLAY — Performance Monitoring
# ============================================================
notify "19/22 — Installing MangoHud + GOverlay"

# MangoHud — Vulkan/OpenGL overlay for FPS, temps, CPU/GPU usage
sudo add-apt-repository -y ppa:flexiondotorg/mangohud 2>/dev/null || true
sudo apt update
sudo apt install -y mangohud mangohud:i386

# GOverlay — GUI configurator for MangoHud
if command -v flatpak &> /dev/null; then
  flatpak install -y flathub com.github.benjamimgois.goverlay || \
    warn "GOverlay Flatpak install failed"
else
  # Install from GitHub releases as fallback
  sudo apt install -y goverlay 2>/dev/null || \
    info "GOverlay not available — configure MangoHud manually or use Flatpak version"
fi

# Create default MangoHud config
mkdir -p ~/.config/MangoHud

cat > ~/.config/MangoHud/MangoHud.conf <<'MANGOEOF'
# MangoHud configuration
# Show FPS, frame times, CPU/GPU stats
# Edit this file or use GOverlay GUI

fps_limit=0
toggle_fps_limit=Shift_L+F1
fps_limit_method=early

legacy_layout=false
horizontal
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
cpu_stats
cpu_temp
cpu_power
ram
vram
fps
frametime
frame_timing=1
engine_version
vulkan_driver
wine
gamemode

position=top-left
background_alpha=0.5
font_size=24
toggle_hud=Shift_R+F12
MANGOEOF

echo "  MangoHud installed"
echo "  Enable in games with: mangohud %command% (Steam launch options)"
echo "  Or: MANGOHUD=1 gamemoderun %command%"
echo "  Toggle HUD: Shift+F12"
echo "  Configure with GOverlay GUI"


# ============================================================
# 20. CORECTRL — AMD GPU/CPU Control
# ============================================================
notify "20/22 — Installing CoreCtrl (AMD GPU/CPU control)"

if [ "$CPU_VENDOR" = "AuthenticAMD" ] || [ "$GPU_AMD" = true ]; then
  info "AMD hardware detected — installing CoreCtrl"
  
  if command -v flatpak &> /dev/null; then
    flatpak install -y flathub org.corectrl.CoreCtrl || \
      warn "CoreCtrl Flatpak install failed"
    
    echo "  CoreCtrl installed via Flatpak"
    echo "  Launch with: flatpak run org.corectrl.CoreCtrl"
  else
    # Alternative: Install from PPA
    sudo add-apt-repository -y ppa:ernstp/mesarc 2>/dev/null || true
    sudo apt update
    sudo apt install -y corectrl 2>/dev/null || \
      info "CoreCtrl PPA not available — use Flatpak version"
  fi
  
  # Enable CoreCtrl to run at startup
  if [ -f /usr/share/applications/org.corectrl.corectrl.desktop ]; then
    mkdir -p ~/.config/autostart
    cp /usr/share/applications/org.corectrl.corectrl.desktop ~/.config/autostart/
  fi
  
  echo "  CoreCtrl allows you to:"
  echo "   - Overclock/underclock AMD GPU"
  echo "   - Control fan curves"
  echo "   - Monitor temps and performance"
  echo "   - Set per-game GPU profiles"
else
  info "No AMD hardware detected — skipping CoreCtrl"
fi


# ============================================================
# 21. PRO AUDIO TOOLS
# ============================================================
notify "21/22 — Installing pro audio tools"

sudo apt install -y \
  qjackctl \
  carla \
  helvum \
  pavucontrol \
  htop

# rtirq-init — IRQ thread priority for audio interfaces
sudo apt install -y rtirq-init
sudo systemctl enable --now rtirq 2>/dev/null || \
  warn "rtirq service could not be enabled — run: sudo systemctl start rtirq"

# cpupower-gui — may not be available, install gracefully
sudo apt install -y cpupower-gui 2>/dev/null || \
  info "cpupower-gui not in repos — use 'sudo cpupower frequency-set -g performance' instead"

# Media codecs
sudo apt install -y media-codec-pack 2>/dev/null || \
  sudo apt install -y ubuntu-restricted-extras 2>/dev/null || \
  info "Media codecs may already be included in Pop!_OS 24.04"


# ============================================================
# 22. FINAL GAMING OPTIMIZATIONS
# ============================================================
notify "22/22 — Applying final gaming optimizations"

# Create gamemode config for even better performance
mkdir -p ~/.config/gamemode

cat > ~/.config/gamemode.ini <<'GAMEMODEEOF'
[general]
; GameMode custom configuration
; See: https://github.com/FeralInteractive/gamemode

; Renice the game process for higher priority
renice=10

; CPU governor — set to performance when gaming
; 0 = no change, 1 = performance
governor=1

; I/O priority — give game better disk access
ioprio=0

[filter]
; Process whitelist — empty means all processes
whitelist=

; Process blacklist
blacklist=

[gpu]
; Apply GPU optimizations when possible
apply_gpu_optimisations=accept

; NVIDIA power mode
nv_powermizer_mode=1

; AMD performance level
amd_performance_level=high
GAMEMODEEOF

echo "  GameMode custom config written to ~/.config/gamemode.ini"

# Create Steam launch options helper
mkdir -p ~/Documents/gaming-notes

cat > ~/Documents/gaming-notes/steam-launch-options.txt <<'STEAMEOF'
# Steam Launch Options — Copy/paste into game properties

# Maximum performance (recommended for most games):
MANGOHUD=1 gamemoderun %command%

# With FPS limit (e.g., 144 fps):
MANGOHUD=1 MANGOHUD_CONFIG=fps_limit=144 gamemoderun %command%

# Force Proton version (replace X-XX with version):
PROTON_VERSION=X-XX MANGOHUD=1 gamemoderun %command%

# Disable in-game overlay issues:
ENABLE_VKBASALT=0 %command%

# Force DXVK async (may help stuttering):
DXVK_ASYNC=1 MANGOHUD=1 gamemoderun %command%

# Disable MangoHud but keep GameMode:
gamemoderun %command%

# Just MangoHud (no GameMode):
MANGOHUD=1 %command%
STEAMEOF

echo "  Steam launch options guide saved to ~/Documents/gaming-notes/steam-launch-options.txt"

# Create quick hardware check script
cat > ~/.local/bin/gaming-check <<'CHECKEOF'
#!/bin/bash
# Quick gaming hardware/software check

echo "=== Gaming Setup Check ==="
echo ""

echo "CPU Governor:"
cpupower frequency-info | grep "current policy" | head -1

echo ""
echo "GPU:"
if command -v nvidia-smi &>/dev/null; then
  nvidia-smi --query-gpu=name,driver_version,temperature.gpu --format=csv,noheader
elif lspci | grep -i "VGA.*AMD" &>/dev/null; then
  lspci | grep -i "VGA.*AMD"
fi

echo ""
echo "Controllers:"
ls /dev/input/js* 2>/dev/null || echo "No controllers detected"

echo ""
echo "Active Services:"
systemctl --user is-active pipewire pipewire-pulse wireplumber gamemode 2>/dev/null | paste -s -d ' '

echo ""
echo "Kernel Parameters:"
cat /proc/cmdline

echo ""
echo "vm.max_map_count: $(sysctl vm.max_map_count | cut -d'=' -f2)"
echo "vm.swappiness: $(sysctl vm.swappiness | cut -d'=' -f2)"

echo ""
echo "=== All checks complete ==="
CHECKEOF

chmod +x ~/.local/bin/gaming-check

echo "  Gaming check script created: gaming-check"
echo "  Run 'gaming-check' anytime to verify your setup"


# ============================================================
# CLEANUP
# ============================================================
notify "Cleaning up"
sudo apt autoremove -y
sudo apt autoclean -y


# ============================================================
# SUMMARY
# ============================================================
echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}  🎮 ULTIMATE GAMING + AUDIO SETUP COMPLETE! 🎮${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${YELLOW}  IMPORTANT — Next steps:${NC}"
echo ""
echo "  ${MAGENTA}1. REBOOT${NC} — Kernel params + drivers require a reboot"
echo ""
echo "  ${MAGENTA}2. VERIFY HARDWARE${NC} (after reboot):"
echo "     Run: ${CYAN}gaming-check${NC}"
echo ""
if [ "$SCARLETT_DETECTED" = true ]; then
echo "  ${MAGENTA}3. SCARLETT 8i6${NC}:"
echo "     Check: ${CYAN}dmesg | grep -i scarlett${NC}"
echo "     Configure: ${CYAN}alsa-scarlett-gui${NC}"
echo ""
fi
echo "  ${MAGENTA}4. PIPEWIRE${NC}:"
echo "     Monitor: ${CYAN}pw-top${NC}"
echo "     Set quantum: ${CYAN}pw-metadata -n settings 0 clock.force-quantum 128${NC}"
echo ""
echo "  ${MAGENTA}5. STEAM SETUP${NC}:"
echo "     → Settings > Compatibility > Enable Steam Play for all titles"
echo "     → Select latest Proton version"
echo "     → Enable controller support in Settings > Controller"
echo ""
echo "  ${MAGENTA}6. PROTON-GE${NC} (better compatibility than regular Proton):"
echo "     Launch: ${CYAN}flatpak run com.vysp3r.ProtonPlus${NC}"
echo "     Download latest Proton-GE, then select it per-game in Steam"
echo ""
if [ "$LOGITECH_DETECTED" = true ]; then
echo "  ${MAGENTA}7. LOGITECH DEVICES${NC}:"
echo "     Configure: ${CYAN}piper${NC}"
echo ""
fi
if [ "$RAZER_DETECTED" = true ]; then
echo "  ${MAGENTA}8. RAZER DEVICES${NC}:"
echo "     Configure: ${CYAN}polychromatic${NC}"
echo "     Log out/in for group changes to take effect"
echo ""
fi
echo "  ${MAGENTA}9. MANGOHUD${NC} (performance overlay):"
echo "     Steam launch options: ${CYAN}MANGOHUD=1 gamemoderun %command%${NC}"
echo "     Configure: ${CYAN}flatpak run com.github.benjamimgois.goverlay${NC}"
echo "     Toggle in-game: ${CYAN}Shift+F12${NC}"
echo ""
echo "  ${MAGENTA}10. CONTROLLERS${NC}:"
if [ "$XBOX_DETECTED" = true ]; then
echo "     Xbox controller already detected and configured"
fi
if [ "$PS4_DETECTED" = true ]; then
echo "     PS4: ${CYAN}systemctl --user start ds4drv${NC}"
fi
if [ "$PS5_DETECTED" = true ]; then
echo "     PS5: ${CYAN}dualsensectl${NC} for LED/rumble control"
fi
echo "     Test: ${CYAN}jstest-gtk${NC}"
echo ""
if [ "$CPU_VENDOR" = "AuthenticAMD" ] || [ "$GPU_AMD" = true ]; then
echo "  ${MAGENTA}11. AMD CONTROL${NC} (CoreCtrl):"
echo "     Launch: ${CYAN}flatpak run org.corectrl.CoreCtrl${NC}"
echo "     Set GPU profiles, overclock, fan curves"
echo ""
fi
echo "  ${MAGENTA}12. AUDIO GROUP${NC}:"
echo "     Log out and back in for audio group membership to take effect"
echo ""
echo "  ${MAGENTA}13. YABRIDGE${NC} (Windows VSTs):"
echo "     After installing VSTs: ${CYAN}yabridgectl sync${NC}"
echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}  📁 Helpful files created:${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo "  ${CYAN}~/Documents/gaming-notes/steam-launch-options.txt${NC}"
echo "  ${CYAN}~/.local/bin/gaming-check${NC} — Hardware/software verification"
echo "  ${CYAN}~/.local/bin/native-access${NC} — Native Instruments helper"
echo "  ${CYAN}~/.config/MangoHud/MangoHud.conf${NC} — Performance overlay config"
echo "  ${CYAN}~/.config/gamemode.ini${NC} — GameMode settings"
echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}  🎸 Happy making music and gaming! 🎮${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
