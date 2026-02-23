#!/bin/bash
# ============================================================
#  Pro Audio + Gaming Setup Script
#  Target: Pop!_OS 24.04 LTS | AMD CPU | NVIDIA RTX 5060
#  Audio Interface: Focusrite Scarlett 8i6
#  Updated from original Ubuntu 22.04 script
# ============================================================
#
# Run with:
#   chmod +x proaudio-setup.sh && ./proaudio-setup.sh
#
# IMPORTANT: Run as your normal user (NOT as root/sudo).
#            The script will call sudo when needed.
#
# What this script does:
#   1. System update
#   2. Focusrite Scarlett 8i6 driver setup (snd_usb_audio)
#   3. PipeWire low-latency tuning (already installed on Pop!_OS 24.04)
#   4. Real-time audio limits (rtprio, memlock)
#   5. Kernel parameters via kernelstub (Pop!_OS uses systemd-boot, NOT grub)
#   6. sysctl tweaks (swappiness, inotify)
#   7. NVIDIA driver + gaming dependencies (RTX 5060)
#   8. Wine Staging (noble/24.04 repo)
#   9. Winetricks
#  10. Yabridge 5.1.0 (Windows VST2/VST3/CLAP bridge)
#  11. Steam + Heroic Games Launcher
#  12. Useful pro-audio tools
# ============================================================

set -e

# ---- Colours -----------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

# ---- Safety check ------------------------------------------
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Do NOT run this script as root. Run as your normal user.${NC}"
  exit 1
fi

# ============================================================
# 1. SYSTEM UPDATE
# ============================================================
notify "1/12 — Updating system packages"
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y


# ============================================================
# 2. FOCUSRITE SCARLETT 8i6 — snd_usb_audio driver setup
#
# On modern kernels (5.14+) the Scarlett driver is built-in,
# but it must be explicitly enabled via module options.
# Gen 2/3/4 devices are fully supported in mainline Linux.
# ============================================================
notify "2/12 — Configuring Focusrite Scarlett 8i6"

# The Scarlett 8i6 USB IDs: vid=0x1235 pid=0x8213
sudo tee /etc/modprobe.d/scarlett.conf > /dev/null <<'EOF'
# Focusrite Scarlett 8i6 — enable full mixer/routing support
# vid=0x1235 is Focusrite, pid=0x8213 is the 8i6
options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1
EOF

echo "  Scarlett 8i6 module config written to /etc/modprobe.d/scarlett.conf"

# Install ALSA Scarlett GUI for visual mixer control
# (Geoffrey Bennett's official control GUI — the best way to manage routing)
sudo apt install -y alsa-scarlett-gui 2>/dev/null || \
  warn "alsa-scarlett-gui not found in repos — you can build it from: https://github.com/geoffreybennett/alsa-scarlett-gui"

# Update initramfs so the option is applied at boot
sudo update-initramfs -u


# ============================================================
# 3. PIPEWIRE LOW-LATENCY TUNING
#
# Pop!_OS 24.04 ships PipeWire + WirePlumber fully configured.
# DO NOT override ~/.config/pipewire/pipewire.conf — it breaks
# WirePlumber's node linking and kills all audio devices.
#
# Instead we:
#   a) Install the JACK bridge for DAWs that need it
#   b) Write a small WirePlumber drop-in for default clock settings
#   c) Document the runtime quantum command for session-by-session tuning
# ============================================================
notify "3/12 — Tuning PipeWire for low-latency pro audio"

# JACK bridge — needed for DAWs that use the JACK API (Ardour, Bitwig, etc.)
sudo apt install -y pipewire-jack pipewire-alsa libspa-0.2-jack

# WirePlumber drop-in for default sample rate and quantum
# This is the correct Pop!_OS safe way — a drop-in, not an override.
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

systemctl --user restart wireplumber pipewire-pulse


# ============================================================
# 4. REAL-TIME AUDIO LIMITS
#    Allows audio apps to use real-time scheduling
# ============================================================
notify "4/12 — Setting real-time audio limits"

sudo tee /etc/security/limits.d/audio.conf > /dev/null <<'EOF'
# Real-time audio — required for DAWs and low-latency audio
@audio - rtprio  90
@audio - memlock unlimited
@audio - nice    -19
EOF

# Add user to audio group
sudo usermod -aG audio "$USER"
echo "  User '$USER' added to audio group (takes effect after logout/login)"


# ============================================================
# 5. KERNEL PARAMETERS via kernelstub
#
# Pop!_OS uses systemd-boot + kernelstub — NOT grub.
# NEVER edit /etc/default/grub on Pop!_OS.
# Use: sudo kernelstub -a "parameter"
# ============================================================
notify "5/12 — Applying kernel parameters via kernelstub"

# threadirqs  — moves IRQ handlers to threads, reduces audio latency
# mitigations=off — disables CPU security mitigations for max performance
#   NOTE: only recommended on a personal machine not exposed to untrusted code
# cpufreq.default_governor=performance — keeps CPU at max freq (no throttling)
# amd_pstate=active — enables AMD P-state driver for better frequency control
#   (important for Ryzen — replaces acpi-cpufreq with native AMD driver)

sudo kernelstub -a "threadirqs"
sudo kernelstub -a "mitigations=off"
sudo kernelstub -a "cpufreq.default_governor=performance"
sudo kernelstub -a "amd_pstate=active"

echo ""
echo "  Current kernel options:"
sudo kernelstub -p 2>/dev/null | grep "Kernel Boot Options" || true
warn "Kernel params take effect after reboot"


# ============================================================
# 6. SYSCTL TWEAKS
#
# We use a DROP-IN file at /etc/sysctl.d/99-proaudio.conf
# instead of editing /etc/sysctl.conf directly.
# This is update-safe: Pop!_OS upgrades never touch sysctl.d/
# and the file is clearly labelled as ours so it's easy to remove.
# ============================================================
notify "6/12 — Applying sysctl tweaks"

sudo tee /etc/sysctl.d/99-proaudio.conf > /dev/null <<'EOF'
# Pro Audio + Gaming sysctl tweaks — Pop!_OS 24.04
# Safe to delete this file to revert all changes.
# See: https://wiki.linuxaudio.org/wiki/system_configuration

# Reduce swap usage — keeps audio buffers in RAM rather than swapping them out.
# 10 = only swap when RAM is 90%+ full (default is 60).
vm.swappiness=10

# More inotify watches — DAWs and plugin managers watch large folder trees.
# Default (8192) is too low for large plugin libraries.
fs.inotify.max_user_watches=600000
EOF

echo "  sysctl drop-in written to /etc/sysctl.d/99-proaudio.conf"
sudo sysctl --system > /dev/null
echo "  sysctl settings applied (also active after every reboot automatically)"


# ============================================================
# 7. NVIDIA RTX 5060 DRIVERS & GAMING DEPENDENCIES
#
# Pop!_OS ships NVIDIA drivers — but the RTX 5060 (Ada Lovelace)
# needs driver 555+ (ideally 570+). Pop!_OS 24.04 should have
# this in its repos. We also install Vulkan and 32-bit libs for gaming.
# ============================================================
notify "7/12 — NVIDIA drivers and gaming dependencies"

# Install latest NVIDIA driver (Pop!_OS manages this, but let's be sure)
sudo apt install -y \
  system76-driver-nvidia \
  nvidia-utils-570 \
  libnvidia-gl-570 \
  libnvidia-gl-570:i386 2>/dev/null || \
  warn "Some NVIDIA packages not found — Pop!_OS may already have the right driver installed. Check via: nvidia-smi"

# Vulkan + 32-bit support (needed for Steam/Proton)
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y \
  vulkan-tools \
  libvulkan1 \
  libvulkan1:i386 \
  mesa-vulkan-drivers \
  mesa-vulkan-drivers:i386

# GameMode — lets games request high-performance mode from the kernel
sudo apt install -y gamemode

echo "  To use GameMode with a game: gamemoderun %command% (in Steam launch options)"


# ============================================================
# 8. WINE STAGING (noble / Ubuntu 24.04 repo)
#
# IMPORTANT CHANGE from original script:
#   - Old script used 'jammy' (22.04) sources — WRONG for 24.04
#   - Pop!_OS 24.04 is based on Ubuntu 24.04 (noble)
#   - Use winehq-noble.sources
# ============================================================
notify "8/12 — Installing Wine Staging"

sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings

# Fetch WineHQ GPG key
sudo wget -O /etc/apt/keyrings/winehq-archive.key \
  https://dl.winehq.org/wine-builds/winehq.key

# Use noble (24.04) sources — NOT jammy
sudo wget -NP /etc/apt/sources.list.d/ \
  https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources

sudo apt update
sudo apt install -y --install-recommends winehq-staging

echo "  Wine Staging installed: $(wine --version 2>/dev/null || echo 'check manually')"


# ============================================================
# 9. WINETRICKS
# ============================================================
notify "9/12 — Installing Winetricks"

sudo apt install -y cabextract
mkdir -p ~/.local/share/winetricks

wget -O ~/.local/share/winetricks/winetricks \
  https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x ~/.local/share/winetricks/winetricks

# Add to PATH if not already there
if ! grep -q "winetricks" ~/.bash_aliases 2>/dev/null; then
  {
    echo ""
    echo "# Winetricks"
    echo 'export PATH="$PATH:$HOME/.local/share/winetricks"'
  } >> ~/.bash_aliases
fi

# shellcheck source=/dev/null
. ~/.bash_aliases 2>/dev/null || true

# Install base Wine fonts (needed for many plugins)
~/.local/share/winetricks/winetricks -q corefonts || \
  warn "winetricks corefonts failed — run manually: winetricks corefonts"

# Save a clean .wine-base copy for creating fresh prefixes later
if [ ! -d ~/.wine-base ]; then
  cp -r ~/.wine ~/.wine-base
  echo "  Saved clean Wine prefix to ~/.wine-base"
fi


# ============================================================
# 10. YABRIDGE 5.1.0 — Windows VST2 / VST3 / CLAP bridge
# ============================================================
notify "10/12 — Installing Yabridge 5.1.0"

YABRIDGE_VERSION="5.1.0"
YABRIDGE_URL="https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/yabridge-${YABRIDGE_VERSION}.tar.gz"

wget -O /tmp/yabridge.tar.gz "$YABRIDGE_URL"
mkdir -p ~/.local/share
tar -C ~/.local/share -xavf /tmp/yabridge.tar.gz
rm /tmp/yabridge.tar.gz

# Add to PATH
if ! grep -q "yabridge" ~/.bash_aliases 2>/dev/null; then
  {
    echo ""
    echo "# Yabridge — Windows VST bridge"
    echo 'export PATH="$PATH:$HOME/.local/share/yabridge"'
  } >> ~/.bash_aliases
fi

. ~/.bash_aliases 2>/dev/null || true

# libnotify is required for yabridge plugin error notifications
sudo apt install -y libnotify-bin

# Create standard VST plugin directories in Wine prefix
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/CLAP"

# Register plugin paths with yabridge
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
~/.local/share/yabridge/yabridgectl add \
  "$HOME/.wine/drive_c/Program Files/Common Files/CLAP"

# Sync yabridge (creates .so files for each registered plugin path)
~/.local/share/yabridge/yabridgectl sync

echo "  After installing Windows VST plugins via Wine,"
echo "  run: yabridgectl sync"
echo "  then rescan plugins in your DAW."


# ============================================================
# 11. STEAM + HEROIC GAMES LAUNCHER
# ============================================================
notify "11/12 — Installing Steam and Heroic"

# Steam (multiverse is enabled by default on Pop!_OS)
sudo apt install -y steam-installer

# Heroic for Epic/GOG games via Flatpak
if command -v flatpak &> /dev/null; then
  flatpak install -y flathub com.heroicgameslauncher.hgl || \
    warn "Heroic Flatpak install failed — try manually from Software Centre"
else
  warn "flatpak not found — install it with: sudo apt install flatpak"
fi

# Enable Proton compatibility layer (do this in Steam settings too)
echo ""
echo "  Steam tip: Enable Steam Play for all titles in:"
echo "  Steam > Settings > Compatibility > Enable Steam Play for all other titles"


# ============================================================
# 12. PRO AUDIO TOOLS
# ============================================================
notify "12/12 — Installing pro audio tools"

# JACK patchbay GUI — useful for monitoring/routing even with PipeWire
# carla — plugin host, great for loading Windows VSTs standalone
# helvum — PipeWire patchbay (modern graphical patchbay)
# pavucontrol — volume/routing control GUI
# rtirq — IRQ thread priority daemon (reduces audio glitches)
# cpupower-gui — GUI to switch CPU governor on the fly
# htop — system monitor
sudo apt install -y \
  qjackctl \
  carla \
  helvum \
  pavucontrol \
  htop

# rtirq-init — correct package name on Ubuntu/Debian (NOT 'rtirq')
# Works with threadirqs kernel param already set via kernelstub above.
# Raises IRQ thread priority for your Scarlett 8i6 automatically at boot.
sudo apt install -y rtirq-init
sudo systemctl enable --now rtirq 2>/dev/null || \
  warn "rtirq service could not be enabled — run: sudo systemctl start rtirq"

# cpupower-gui — may not be in Pop!_OS repos, install gracefully
sudo apt install -y cpupower-gui 2>/dev/null || \
  warn "cpupower-gui not in repos — use 'sudo cpupower frequency-set -g performance' from terminal instead"

# Media codecs — try Pop!_OS specific pack first, fall back to ubuntu-restricted-extras
sudo apt install -y media-codec-pack 2>/dev/null || \
  sudo apt install -y ubuntu-restricted-extras 2>/dev/null || \
  warn "No media codec pack found — codecs may already be included in Pop!_OS 24.04"


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
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${YELLOW}  Next steps (important):${NC}"
echo ""
echo "  1. REBOOT — kernel params + module changes require a reboot"
echo ""
echo "  2. SCARLETT 8i6 — after reboot, check it's working:"
echo "       dmesg | grep -i scarlett"
echo "     If you see 'Focusrite Scarlett Gen 2/3 Mixer Driver enabled' you're good."
echo "     Launch: alsa-scarlett-gui  (to configure routing visually)"
echo ""
echo "  3. PIPEWIRE — verify low-latency mode:"
echo "       pw-top   (check your DAW's quantum matches your config)"
echo "     Runtime quantum change (no reboot needed):"
echo "       pw-metadata -n settings 0 clock.force-quantum 128"
echo ""
echo "  4. CPU GOVERNOR — confirm performance mode after reboot:"
echo "       cpupower frequency-info | grep 'current policy'"
echo ""
echo "  5. NVIDIA — verify RTX 5060 detected:"
echo "       nvidia-smi"
echo ""
echo "  6. AUDIO GROUP — log out and back in for group changes to take effect"
echo ""
echo "  7. YABRIDGE — after installing Windows VSTs via Wine:"
echo "       yabridgectl sync"
echo "     then rescan in your DAW."
echo ""
echo -e "${GREEN}  Happy making music and gaming!${NC}"
echo ""
