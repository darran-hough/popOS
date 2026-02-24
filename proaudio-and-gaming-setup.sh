#!/bin/bash
# ============================================================
#  Pro Audio + Gaming Setup Script (IDEMPOTENT EDITION)
#  Target: Pop!_OS 24.04 LTS | AMD CPU | NVIDIA RTX 5060
#  Audio Interface: Focusrite Scarlett 8i6
#  
#  SAFE TO RUN MULTIPLE TIMES
#  All operations check if already completed before executing
# ============================================================
#
# Run with:
#   chmod +x proaudio-gaming-idempotent.sh && ./proaudio-gaming-idempotent.sh
#
# IMPORTANT: Run as your normal user (NOT as root/sudo).
#            The script will call sudo when needed.
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

skip() {
  echo -e "${MAGENTA}  [SKIP] $1${NC}"
}

# ---- Safety check ------------------------------------------
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Do NOT run this script as root. Run as your normal user.${NC}"
  exit 1
fi

# ============================================================
# PRE-FLIGHT — Remove known broken PPAs before any apt update
# ============================================================
notify "PRE-FLIGHT — Removing known broken PPAs"

if grep -r "flexiondotorg/mangohud" /etc/apt/sources.list.d/ 2>/dev/null | grep -q "mangohud"; then
  warn "Removing incompatible flexiondotorg/mangohud PPA (causes apt errors)..."
  sudo add-apt-repository --remove ppa:flexiondotorg/mangohud -y 2>/dev/null || true
  info "Removed. MangoHud will be installed from official Ubuntu repos."
else
  skip "No broken MangoHud PPA found — continuing"
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

  if [ -f /etc/modprobe.d/scarlett.conf ]; then
    skip "Scarlett config already exists"
  else
    sudo tee /etc/modprobe.d/scarlett.conf > /dev/null <<'EOF'
# Focusrite Scarlett 8i6 — enable full mixer/routing support
# vid=0x1235 is Focusrite, pid=0x8213 is the 8i6
options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1
EOF
    echo "  Scarlett 8i6 module config written to /etc/modprobe.d/scarlett.conf"
    sudo update-initramfs -u
  fi

  if ! dpkg -l | grep -q alsa-scarlett-gui; then
    sudo apt install -y alsa-scarlett-gui 2>/dev/null || \
      warn "alsa-scarlett-gui not found in repos"
  else
    skip "alsa-scarlett-gui already installed"
  fi
else
  notify "3/22 — Skipping Scarlett setup (no device detected)"
fi


# ============================================================
# 4. PIPEWIRE LOW-LATENCY TUNING
# ============================================================
notify "4/22 — Tuning PipeWire for low-latency pro audio"

sudo apt install -y pipewire-jack pipewire-alsa libspa-0.2-jack

mkdir -p ~/.config/wireplumber/wireplumber.conf.d

if [ -f ~/.config/wireplumber/wireplumber.conf.d/50-pro-audio.conf ]; then
  skip "PipeWire config already exists"
else
  cat > ~/.config/wireplumber/wireplumber.conf.d/50-pro-audio.conf <<'EOF'
# Pro audio tuning drop-in for Pop!_OS 24.04
# Safe to delete to revert: rm ~/.config/wireplumber/wireplumber.conf.d/50-pro-audio.conf

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
  echo "  WirePlumber drop-in written"
fi

echo ""
echo "  To change quantum at runtime:"
echo "    pw-metadata -n settings 0 clock.force-quantum 128"

systemctl --user restart wireplumber pipewire-pulse 2>/dev/null || true


# ============================================================
# 5. REAL-TIME AUDIO LIMITS
# ============================================================
notify "5/22 — Setting real-time audio limits"

if [ -f /etc/security/limits.d/audio.conf ]; then
  skip "Audio limits already configured"
else
  sudo tee /etc/security/limits.d/audio.conf > /dev/null <<'EOF'
# Real-time audio — required for DAWs and low-latency audio
@audio - rtprio  90
@audio - memlock unlimited
@audio - nice    -19
EOF
  echo "  Audio limits configured"
fi

if groups $USER | grep -q audio; then
  skip "User already in audio group"
else
  sudo usermod -aG audio "$USER"
  echo "  User '$USER' added to audio group (takes effect after logout/login)"
fi


# ============================================================
# 6. KERNEL PARAMETERS via kernelstub
# ============================================================
notify "6/22 — Applying kernel parameters via kernelstub"

# Function to add kernel parameter if not already present
add_kernel_param() {
  local param=$1
  if sudo kernelstub -p 2>/dev/null | grep -q "$param"; then
    skip "Kernel parameter already set: $param"
  else
    sudo kernelstub -a "$param"
    echo "  Added kernel parameter: $param"
  fi
}

# Remove conflicting parameters first
sudo kernelstub -d "mitigations=auto" 2>/dev/null || true
sudo kernelstub -d "split_lock_detect=fatal" 2>/dev/null || true

# Add gaming + audio optimized parameters
add_kernel_param "threadirqs"
add_kernel_param "mitigations=off"
add_kernel_param "split_lock_detect=off"
add_kernel_param "cpufreq.default_governor=performance"
add_kernel_param "transparent_hugepage=always"

if [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
  add_kernel_param "amd_pstate=active"
fi

if [ "$GPU_AMD" = true ]; then
  add_kernel_param "amdgpu.ppfeaturemask=0xffffffff"
fi

echo ""
echo "  Current kernel options:"
sudo kernelstub -p 2>/dev/null | grep "Kernel Boot Options" || true
warn "Kernel params take effect after reboot"


# ============================================================
# 7. SYSCTL TWEAKS
# ============================================================
notify "7/22 — Applying sysctl tweaks (gaming + audio)"

if [ -f /etc/sysctl.d/99-proaudio-gaming.conf ]; then
  skip "sysctl config already exists"
else
  sudo tee /etc/sysctl.d/99-proaudio-gaming.conf > /dev/null <<'EOF'
# Pro Audio + Gaming sysctl tweaks — Pop!_OS 24.04
vm.swappiness=10
fs.inotify.max_user_watches=600000
vm.max_map_count=1048576
fs.file-max=2097152
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=1048576
net.core.wmem_default=1048576
net.ipv4.tcp_rmem=4096 1048576 16777216
net.ipv4.tcp_wmem=4096 1048576 16777216
net.core.netdev_max_backlog=5000
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_timestamps=0
EOF
  echo "  sysctl drop-in written"
  sudo sysctl --system > /dev/null
fi


# ============================================================
# 8. NVIDIA DRIVERS & GAMING DEPENDENCIES
# ============================================================
notify "8/22 — NVIDIA drivers and gaming dependencies"

if [ "$GPU_NVIDIA" = true ]; then
  sudo apt install -y \
    system76-driver-nvidia \
    nvidia-utils-570 \
    libnvidia-gl-570 2>/dev/null || true
  
  sudo dpkg --add-architecture i386 2>/dev/null || true
  sudo apt update || true
  sudo apt install -y libnvidia-gl-570:i386 2>/dev/null || true
  
  if [ -f /etc/modprobe.d/nvidia-power.conf ]; then
    skip "NVIDIA power config already exists"
  else
    sudo tee /etc/modprobe.d/nvidia-power.conf > /dev/null <<'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
    sudo update-initramfs -u
  fi
  
  info "NVIDIA driver configured"
else
  skip "No NVIDIA GPU detected"
fi

# Vulkan + 32-bit support
sudo dpkg --add-architecture i386 2>/dev/null || true
sudo apt update || true
sudo apt install -y \
  vulkan-tools \
  libvulkan1 \
  libvulkan1:i386 \
  mesa-vulkan-drivers \
  mesa-vulkan-drivers:i386

# GameMode
sudo apt install -y gamemode lib32-gamemode 2>/dev/null || sudo apt install -y gamemode


# ============================================================
# 9. WINE
# ============================================================
notify "9/22 — Installing Wine"

sudo dpkg --add-architecture i386 2>/dev/null || true
sudo apt update || true
sudo apt install -y wine wine64 wine32 winbind libntlm0

echo "  Wine installed: $(wine --version 2>/dev/null || echo 'check manually')"

# Wine desktop integration
mkdir -p ~/.local/share/applications

if [ -f ~/.local/share/applications/wine.desktop ]; then
  skip "Wine desktop entry already exists"
else
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
  xdg-mime default wine.desktop application/x-ms-dos-executable 2>/dev/null || true
  xdg-mime default wine.desktop application/x-msdownload 2>/dev/null || true
fi

if [ -f ~/.local/share/applications/wine-msi.desktop ]; then
  skip "Wine MSI entry already exists"
else
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
  xdg-mime default wine-msi.desktop application/x-msi 2>/dev/null || true
fi

update-desktop-database ~/.local/share/applications 2>/dev/null || true


# ============================================================
# 10. WINETRICKS + WINDOWS RUNTIMES
# ============================================================
notify "10/22 — Installing Winetricks and Windows runtime dependencies"

sudo apt install -y cabextract
mkdir -p ~/.local/share/winetricks

if [ -f ~/.local/share/winetricks/winetricks ]; then
  skip "Winetricks already installed"
else
  wget -O ~/.local/share/winetricks/winetricks \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
  chmod +x ~/.local/share/winetricks/winetricks
fi

# Add to PATH if not already there
if ! grep -q "winetricks" ~/.bash_aliases 2>/dev/null; then
  {
    echo ""
    echo "# Winetricks"
    echo 'export PATH="$PATH:$HOME/.local/share/winetricks"'
  } >> ~/.bash_aliases
fi

. ~/.bash_aliases 2>/dev/null || true

# Only run winetricks if Wine prefix exists but components aren't installed
if [ ! -d ~/.wine ]; then
  info "First-time Wine setup - this may take 10-15 minutes..."
  
  # Set Wine to Windows 10 mode
  WINEDLLOVERRIDES="mscoree,mshtml=" winecfg /v win10
  
  # Install components with output filtering
  info "Installing core fonts..."
  ~/.local/share/winetricks/winetricks -q corefonts 2>&1 | grep -v "TransformView_set_row" || true
  
  info "Installing Visual C++ runtimes (this takes a while)..."
  for vcrun in vcrun2013 vcrun2015 vcrun2019 vcrun2022; do
    wineserver -k 2>/dev/null || true
    sleep 1
    ~/.local/share/winetricks/winetricks -q $vcrun 2>&1 | grep -v "TransformView_set_row\|CoGetContextToken\|CoReleaseMarshalData" || true
    wineserver -k 2>/dev/null || true
  done
  
  info "Installing additional components..."
  for component in gdiplus mfc42 mfc140 urlmon wininet dxvk; do
    wineserver -k 2>/dev/null || true
    ~/.local/share/winetricks/winetricks -q $component 2>&1 | grep -v "TransformView_set_row" || true
  done
  
  info "Installing .NET Framework (optional, may take 5-10 minutes)..."
  info "You can skip .NET installation by pressing Ctrl+C - most things will still work"
  sleep 3
  
  wineserver -k 2>/dev/null || true
  sleep 2
  ~/.local/share/winetricks/winetricks -q dotnet35 2>&1 | grep -v "TransformView_set_row\|CoGetContextToken\|CoReleaseMarshalData\|Read access denied" || warn ".NET 3.5 installation had warnings (usually safe)"
  
  wineserver -k 2>/dev/null || true
  sleep 2
  ~/.local/share/winetricks/winetricks -q dotnet48 2>&1 | grep -v "TransformView_set_row\|CoGetContextToken\|CoReleaseMarshalData\|Read access denied" || warn ".NET 4.8 installation had warnings (usually safe)"
  
  wineserver -k 2>/dev/null || true
  
  info "Wine runtime installation complete"
else
  skip "Wine prefix already exists - skipping winetricks installation"
  info "To reinstall Wine components, delete ~/.wine and run this script again"
fi

# Create required directories
mkdir -p "$HOME/.wine/drive_c/users/Public/Downloads"
mkdir -p "$HOME/.wine/drive_c/users/$USER/Downloads"
mkdir -p "$HOME/.wine/drive_c/users/$USER/Desktop"
mkdir -p "$HOME/.wine/drive_c/users/$USER/Documents"

# Save clean Wine prefix backup if doesn't exist
if [ ! -d ~/.wine-base ] && [ -d ~/.wine ]; then
  info "Creating backup of Wine prefix..."
  cp -r ~/.wine ~/.wine-base
  echo "  Saved clean Wine prefix to ~/.wine-base"
fi

# Native Instruments helper
if [ ! -f ~/.local/bin/native-access ]; then
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
if [ ! -f "$NA_INSTALLER" ] || [ ! -s "$NA_INSTALLER" ]; then
  echo "Downloading Native Access 2 installer..."
  mkdir -p "$HOME/.cache/native-access"
  wget -q --show-progress "$NA_DOWNLOAD_URL" -O "$NA_INSTALLER"
fi

if [ -f "$NA_INSTALLER" ] && [ -s "$NA_INSTALLER" ]; then
  echo "Running installer..."
  wine "$NA_INSTALLER"
  sleep 5
  if [ -f "$NATIVE_ACCESS" ]; then
    wine "$NTKDAEMON" &
    sleep 4
    wine "$NATIVE_ACCESS"
  fi
fi
NAEOF
  chmod +x ~/.local/bin/native-access
fi

if ! grep -q 'HOME/.local/bin' ~/.bash_aliases 2>/dev/null; then
  echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bash_aliases
fi


# ============================================================
# 11. YABRIDGE 5.1.0
# ============================================================
notify "11/22 — Installing Yabridge 5.1.0"

if [ -d ~/.local/share/yabridge ] && [ -f ~/.local/share/yabridge/yabridgectl ]; then
  skip "Yabridge already installed"
else
  YABRIDGE_VERSION="5.1.0"
  YABRIDGE_URL="https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/yabridge-${YABRIDGE_VERSION}.tar.gz"
  
  wget -O /tmp/yabridge.tar.gz "$YABRIDGE_URL"
  mkdir -p ~/.local/share
  tar -C ~/.local/share -xavf /tmp/yabridge.tar.gz
  rm /tmp/yabridge.tar.gz
  echo "  Yabridge installed"
fi

if ! grep -q "yabridge" ~/.bash_aliases 2>/dev/null; then
  {
    echo ""
    echo "# Yabridge — Windows VST bridge"
    echo 'export PATH="$PATH:$HOME/.local/share/yabridge"'
  } >> ~/.bash_aliases
fi

. ~/.bash_aliases 2>/dev/null || true

sudo apt install -y libnotify-bin

# Create VST directories
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/CLAP"

# Register plugin paths (yabridgectl handles duplicates automatically)
~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins" 2>/dev/null || skip "VST path already registered"
~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2" 2>/dev/null || skip "VST2 path already registered"
~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3" 2>/dev/null || skip "VST3 path already registered"
~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/CLAP" 2>/dev/null || skip "CLAP path already registered"

~/.local/share/yabridge/yabridgectl sync


# ============================================================
# 12. STEAM + PROTON CONFIGURATION
# ============================================================
notify "12/22 — Installing Steam and configuring Proton"

sudo apt install -y steam-installer

if [ -f /etc/udev/rules.d/70-steam-controller.rules ]; then
  skip "Steam controller udev rules already exist"
else
  sudo tee /etc/udev/rules.d/70-steam-controller.rules > /dev/null <<'EOF'
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
EOF
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi


# ============================================================
# 13. HEROIC GAMES LAUNCHER
# ============================================================
notify "13/22 — Installing Heroic Games Launcher"

if command -v flatpak &> /dev/null; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  
  if flatpak list | grep -q com.heroicgameslauncher.hgl; then
    skip "Heroic already installed"
  else
    flatpak install -y flathub com.heroicgameslauncher.hgl || warn "Heroic install failed"
  fi
else
  warn "Flatpak not found - installing it"
  sudo apt install -y flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub com.heroicgameslauncher.hgl || warn "Heroic install failed"
fi


# ============================================================
# 14. PROTONPLUS
# ============================================================
notify "14/22 — Installing ProtonPlus"

if command -v flatpak &> /dev/null; then
  if flatpak list | grep -q com.vysp3r.ProtonPlus; then
    skip "ProtonPlus already installed"
  else
    flatpak install -y flathub com.vysp3r.ProtonPlus || warn "ProtonPlus install failed"
  fi
fi


# ============================================================
# 15. LUTRIS
# ============================================================
notify "15/22 — Installing Lutris"

if grep -r "lutris-team" /etc/apt/sources.list.d/ 2>/dev/null | grep -q "lutris"; then
  skip "Lutris PPA already added"
else
  sudo add-apt-repository -y ppa:lutris-team/lutris 2>/dev/null || true
  sudo apt update || true
fi

sudo apt install -y lutris


# ============================================================
# 16. LOGITECH PERIPHERAL SUPPORT
# ============================================================
notify "16/22 — Installing Logitech peripheral support (Piper)"

if [ "$LOGITECH_DETECTED" = true ]; then
  sudo apt install -y piper
  sudo systemctl enable --now ratbagd 2>/dev/null || true
  echo "  Piper installed"
else
  skip "No Logitech devices detected"
fi


# ============================================================
# 17. RAZER PERIPHERAL SUPPORT
# ============================================================
notify "17/22 — Installing Razer peripheral support (OpenRazer)"

if [ "$RAZER_DETECTED" = true ]; then
  if grep -r "openrazer" /etc/apt/sources.list.d/ 2>/dev/null | grep -q "openrazer"; then
    skip "OpenRazer PPA already added"
  else
    sudo add-apt-repository -y ppa:openrazer/stable 2>/dev/null || true
    sudo apt update || true
  fi
  
  sudo apt install -y openrazer-meta polychromatic
  
  if groups $USER | grep -q plugdev; then
    skip "User already in plugdev group"
  else
    sudo usermod -aG plugdev "$USER"
    echo "  User added to plugdev group"
  fi
else
  skip "No Razer devices detected"
fi


# ============================================================
# 18. CONTROLLER SUPPORT
# ============================================================
notify "18/22 — Installing controller support"

# Xbox controller support
if [ "$XBOX_DETECTED" = true ]; then
  if [ ! -d /tmp/xpadneo ] || [ ! -d /usr/src/hid-xpadneo-* ]; then
    info "Installing xpadneo for Xbox controllers..."
    sudo apt install -y dkms linux-headers-generic
    git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo 2>/dev/null || true
    cd /tmp/xpadneo
    sudo ./install.sh
    cd -
  else
    skip "xpadneo already installed"
  fi
fi

# PS4 controller support
if [ "$PS4_DETECTED" = true ]; then
  if ! command -v ds4drv &> /dev/null; then
    info "Installing ds4drv for PS4 controllers..."
    sudo apt install -y python3-pip
    sudo pip3 install ds4drv --break-system-packages 2>/dev/null || true
    
    mkdir -p ~/.config/systemd/user
    if [ ! -f ~/.config/systemd/user/ds4drv.service ]; then
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
    fi
  else
    skip "ds4drv already installed"
  fi
fi

# PS5 controller support
if [ "$PS5_DETECTED" = true ]; then
  if ! command -v dualsensectl &> /dev/null; then
    info "Installing dualsensectl for PS5 controllers..."
    sudo apt install -y build-essential pkg-config libdbus-1-dev libhidapi-dev
    if [ ! -d /tmp/dualsensectl ]; then
      git clone https://github.com/nowrep/dualsensectl.git /tmp/dualsensectl
      cd /tmp/dualsensectl
      make
      sudo make install
      cd -
    fi
  else
    skip "dualsensectl already installed"
  fi
fi

sudo apt install -y joystick jstest-gtk


# ============================================================
# 19. MANGOHUD + GOVERLAY
# ============================================================
notify "19/22 — Installing MangoHud + GOverlay"

# Note: broken flexiondotorg/mangohud PPA was already removed in PRE-FLIGHT above

sudo apt install -y mangohud lib32-mangohud 2>/dev/null || sudo apt install -y mangohud

if dpkg --print-foreign-architectures | grep -q i386; then
  sudo apt install -y mangohud:i386 2>/dev/null || warn "32-bit MangoHud not available"
fi

if command -v flatpak &> /dev/null; then
  if flatpak list | grep -q com.github.benjamimgois.goverlay; then
    skip "GOverlay already installed"
  else
    flatpak install -y flathub com.github.benjamimgois.goverlay || warn "GOverlay install failed"
  fi
fi

# Create MangoHud config
mkdir -p ~/.config/MangoHud

if [ -f ~/.config/MangoHud/MangoHud.conf ]; then
  skip "MangoHud config already exists"
else
  cat > ~/.config/MangoHud/MangoHud.conf <<'MANGOEOF'
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
  echo "  MangoHud config created"
fi


# ============================================================
# 20. CORECTRL
# ============================================================
notify "20/22 — Installing CoreCtrl (AMD GPU/CPU control)"

if [ "$CPU_VENDOR" = "AuthenticAMD" ] || [ "$GPU_AMD" = true ]; then
  if command -v flatpak &> /dev/null; then
    if flatpak list | grep -q org.corectrl.CoreCtrl; then
      skip "CoreCtrl already installed"
    else
      flatpak install -y flathub org.corectrl.CoreCtrl || warn "CoreCtrl install failed"
    fi
  fi
else
  skip "No AMD hardware detected"
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

sudo apt install -y rtirq-init
if ! systemctl is-enabled rtirq &>/dev/null; then
  sudo systemctl enable --now rtirq 2>/dev/null || warn "rtirq service could not be enabled"
else
  skip "rtirq already enabled"
fi

sudo apt install -y cpupower-gui 2>/dev/null || info "cpupower-gui not available"
sudo apt install -y ubuntu-restricted-extras 2>/dev/null || true


# ============================================================
# 22. FINAL GAMING OPTIMIZATIONS
# ============================================================
notify "22/22 — Applying final gaming optimizations"

# GameMode config
mkdir -p ~/.config/gamemode

if [ -f ~/.config/gamemode.ini ]; then
  skip "GameMode config already exists"
else
  cat > ~/.config/gamemode.ini <<'GAMEMODEEOF'
[general]
renice=10
governor=1
ioprio=0

[filter]
whitelist=
blacklist=

[gpu]
apply_gpu_optimisations=accept
nv_powermizer_mode=1
amd_performance_level=high
GAMEMODEEOF
  echo "  GameMode config created"
fi

# Steam launch options guide
mkdir -p ~/Documents/gaming-notes

if [ ! -f ~/Documents/gaming-notes/steam-launch-options.txt ]; then
  cat > ~/Documents/gaming-notes/steam-launch-options.txt <<'STEAMEOF'
# Steam Launch Options — Copy/paste into game properties

# Maximum performance (recommended):
MANGOHUD=1 gamemoderun %command%

# With FPS limit (e.g., 144 fps):
MANGOHUD=1 MANGOHUD_CONFIG=fps_limit=144 gamemoderun %command%

# Force DXVK async (may help stuttering):
DXVK_ASYNC=1 MANGOHUD=1 gamemoderun %command%

# Disable MangoHud but keep GameMode:
gamemoderun %command%
STEAMEOF
fi

# Gaming check script
if [ ! -f ~/.local/bin/gaming-check ]; then
  mkdir -p ~/.local/bin
  cat > ~/.local/bin/gaming-check <<'CHECKEOF'
#!/bin/bash
echo "=== Gaming Setup Check ==="
echo ""
echo "CPU Governor:"
cpupower frequency-info 2>/dev/null | grep "current policy" | head -1 || echo "cpupower not available"
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
echo "vm.max_map_count: $(sysctl vm.max_map_count | cut -d'=' -f2)"
echo "vm.swappiness: $(sysctl vm.swappiness | cut -d'=' -f2)"
echo ""
echo "=== All checks complete ==="
CHECKEOF
  chmod +x ~/.local/bin/gaming-check
fi


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
echo -e "${GREEN}  🎮 SETUP COMPLETE! 🎮${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${YELLOW}  IMPORTANT — Next steps:${NC}"
echo ""
echo "  ${MAGENTA}1. REBOOT${NC} — Kernel params require a reboot"
echo ""
echo "  ${MAGENTA}2. VERIFY SETUP${NC} (after reboot):"
echo "     Run: ${CYAN}gaming-check${NC}"
echo ""
if [ "$SCARLETT_DETECTED" = true ]; then
echo "  ${MAGENTA}3. SCARLETT 8i6${NC}:"
echo "     Check: ${CYAN}dmesg | grep -i scarlett${NC}"
echo "     Configure: ${CYAN}alsa-scarlett-gui${NC}"
echo ""
fi
echo "  ${MAGENTA}4. STEAM SETUP${NC}:"
echo "     → Settings > Compatibility > Enable Steam Play for all titles"
echo "     → Select latest Proton version"
echo ""
echo "  ${MAGENTA}5. PROTON-GE${NC}:"
echo "     Launch: ${CYAN}flatpak run com.vysp3r.ProtonPlus${NC}"
echo ""
echo "  ${MAGENTA}6. MANGOHUD${NC}:"
echo "     Steam launch options: ${CYAN}MANGOHUD=1 gamemoderun %command%${NC}"
echo "     Toggle in-game: ${CYAN}Shift+F12${NC}"
echo ""
echo -e "${GREEN}  This script is safe to run multiple times!${NC}"
echo -e "${GREEN}  It checks existing configs before making changes.${NC}"
echo ""
echo -e "${GREEN}  Happy gaming and music-making! 🎸🎮${NC}"
echo ""
