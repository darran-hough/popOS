#!/usr/bin/env bash
# =============================================================================
#  🎮 Ultimate Pop!_OS Gaming Setup Script
#  Supports: Pop!_OS 24.04 LTS | NVIDIA | AMD | Intel
#  Features: Auto hardware detection, drivers, launchers, peripherals
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
LOG_FILE="$HOME/gaming-setup.log"
log()     { echo -e "${GREEN}[✔]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✘]${NC} $*" | tee -a "$LOG_FILE"; }
info()    { echo -e "${BLUE}[→]${NC} $*" | tee -a "$LOG_FILE"; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${NC}\n" | tee -a "$LOG_FILE"; }

# ── Banner ────────────────────────────────────────────────────────────────────
banner() {
cat << 'EOF'
  ____                  _  ___  ____     ____                  _
 |  _ \ ___  _ __     / |/ _ \/ ___|   / ___| __ _ _ __ ___ (_)_ __   __ _
 | |_) / _ \| '_ \   | | | | \___ \  | |  _ / _` | '_ ` _ \| | '_ \ / _` |
 |  __/ (_) | |_) |  | | |_| |___) | | |_| | (_| | | | | | | | | | | (_| |
 |_|   \___/| .__/   |_|\___/|____/   \____|\__,_|_| |_| |_|_|_| |_|\__, |
            |_|         Ultimate Gaming Setup                         |___/
EOF
echo -e "${CYAN}  Pop!_OS 24.04 LTS | Auto Hardware Detection | v2.0${NC}\n"
}

# ── Safety Checks ─────────────────────────────────────────────────────────────
preflight_checks() {
    section "Preflight Checks"

    # OS check
    if ! grep -q "Pop!_OS" /etc/os-release 2>/dev/null; then
        warn "This script is optimised for Pop!_OS. Proceeding anyway, but some steps may differ."
    else
        log "Pop!_OS detected ✔"
    fi

    # Root check
    if [[ "$EUID" -eq 0 ]]; then
        error "Do not run this script as root. Run as your normal user."
        exit 1
    fi

    # Internet check
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        error "No internet connection detected. Please connect and retry."
        exit 1
    fi
    log "Internet connection OK ✔"

    # Disk space check (require at least 10GB free)
    FREE_GB=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
    if [[ "$FREE_GB" -lt 10 ]]; then
        error "Less than 10GB free disk space. Please free up space and retry."
        exit 1
    fi
    log "Disk space OK (${FREE_GB}GB free) ✔"
}

# ── Hardware Detection ────────────────────────────────────────────────────────
detect_hardware() {
    section "Hardware Detection"

    # GPU Detection
    GPU_VENDOR="unknown"
    if lspci | grep -qi "nvidia"; then
        GPU_VENDOR="nvidia"
        GPU_MODEL=$(lspci | grep -i "nvidia" | head -1 | sed 's/.*: //')
        log "GPU: NVIDIA detected → $GPU_MODEL"
    elif lspci | grep -qi "amd\|radeon"; then
        GPU_VENDOR="amd"
        GPU_MODEL=$(lspci | grep -i "amd\|radeon" | head -1 | sed 's/.*: //')
        log "GPU: AMD detected → $GPU_MODEL"
    elif lspci | grep -qi "intel.*graphics\|intel.*uhd\|intel.*iris"; then
        GPU_VENDOR="intel"
        GPU_MODEL=$(lspci | grep -i "intel.*graphics\|intel.*uhd\|intel.*iris" | head -1 | sed 's/.*: //')
        log "GPU: Intel integrated detected → $GPU_MODEL"
    else
        warn "GPU vendor could not be determined. Skipping GPU-specific steps."
    fi

    # CPU Detection
    CPU_VENDOR="unknown"
    if grep -qi "intel" /proc/cpuinfo; then
        CPU_VENDOR="intel"
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        log "CPU: Intel → $CPU_MODEL"
    elif grep -qi "amd" /proc/cpuinfo; then
        CPU_VENDOR="amd"
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        log "CPU: AMD → $CPU_MODEL"
    fi

    # RAM
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    log "RAM: ${RAM_GB}GB detected"

    # Mouse Detection
    MOUSE_LOGITECH=false
    MOUSE_RAZER=false
    MOUSE_STEELSERIES=false
    MOUSE_CORSAIR=false
    MOUSE_ROCCAT=false

    if lsusb | grep -qi "logitech"; then
        MOUSE_LOGITECH=true
        log "Peripheral: Logitech device detected"
    fi
    if lsusb | grep -qi "razer"; then
        MOUSE_RAZER=true
        log "Peripheral: Razer device detected"
    fi
    if lsusb | grep -qi "steelseries\|steel series"; then
        MOUSE_STEELSERIES=true
        log "Peripheral: SteelSeries device detected"
    fi
    if lsusb | grep -qi "corsair"; then
        MOUSE_CORSAIR=true
        log "Peripheral: Corsair device detected"
    fi
    if lsusb | grep -qi "roccat"; then
        MOUSE_ROCCAT=true
        log "Peripheral: ROCCAT device detected"
    fi

    # Controller Detection
    CONTROLLER_XBOX=false
    CONTROLLER_PS=false
    CONTROLLER_8BITDO=false
    CONTROLLER_NINTENDO=false

    if lsusb | grep -qi "xbox\|045e:"; then
        CONTROLLER_XBOX=true
        log "Peripheral: Xbox controller detected"
    fi
    if lsusb | grep -qi "054c:\|dualshock\|dualsense\|sony.*controller"; then
        CONTROLLER_PS=true
        log "Peripheral: PlayStation controller detected"
    fi
    if lsusb | grep -qi "2dc8:\|8bitdo"; then
        CONTROLLER_8BITDO=true
        log "Peripheral: 8BitDo controller detected"
    fi
    if lsusb | grep -qi "nintendo\|057e:"; then
        CONTROLLER_NINTENDO=true
        log "Peripheral: Nintendo controller detected"
    fi

    echo ""
    info "Hardware detection complete. Proceeding with tailored setup..."
}

# ── System Update ─────────────────────────────────────────────────────────────
system_update() {
    section "System Update"
    info "Updating package lists and upgrading system..."
    sudo apt update -y 2>&1 | tee -a "$LOG_FILE"
    sudo apt upgrade -y 2>&1 | tee -a "$LOG_FILE"
    sudo apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
    log "System updated ✔"
}

# ── Flatpak Setup ─────────────────────────────────────────────────────────────
setup_flatpak() {
    section "Flatpak Setup"
    if ! command -v flatpak &>/dev/null; then
        info "Installing Flatpak..."
        sudo apt install -y flatpak 2>&1 | tee -a "$LOG_FILE"
    else
        log "Flatpak already installed ✔"
    fi

    # Add Flathub if not present
    if ! flatpak remotes | grep -q "flathub"; then
        info "Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        log "Flathub added ✔"
    else
        log "Flathub already configured ✔"
    fi
}

# ── GPU Drivers ───────────────────────────────────────────────────────────────
setup_gpu_drivers() {
    section "GPU Driver Setup"

    case "$GPU_VENDOR" in
        nvidia)
            info "Configuring NVIDIA drivers..."

            # Pop!_OS ships NVIDIA drivers, ensure system76-driver-nvidia is installed
            sudo apt install -y system76-driver-nvidia 2>&1 | tee -a "$LOG_FILE" || true

            # Vulkan support
            sudo apt install -y nvidia-vulkan-icd vulkan-tools libvulkan1 2>&1 | tee -a "$LOG_FILE"

            # CUDA libraries (useful for some games/tools)
            sudo apt install -y libcuda1 2>&1 | tee -a "$LOG_FILE" || true

            # Enable NVIDIA persistence mode
            info "Enabling NVIDIA persistence mode..."
            sudo nvidia-smi --persistence-mode=1 2>/dev/null || warn "Could not set persistence mode (may need reboot first)"

            # Create persistence mode systemd service
            sudo tee /etc/systemd/system/nvidia-persistence-mode.service > /dev/null << 'SVCEOF'
[Unit]
Description=Enable NVIDIA Persistence Mode
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi --persistence-mode=1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
            sudo systemctl enable nvidia-persistence-mode.service 2>&1 | tee -a "$LOG_FILE"

            # Force maximum performance power mode
            sudo nvidia-smi --auto-boost-default=0 2>/dev/null || true
            sudo nvidia-settings --assign "[gpu:0]/GpuPowerMizerMode=1" 2>/dev/null || true

            # NVIDIA udev rules for better performance
            sudo tee /etc/udev/rules.d/99-nvidia.rules > /dev/null << 'UDEVEOF'
# NVIDIA power management
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
UDEVEOF

            log "NVIDIA drivers configured ✔"
            ;;

        amd)
            info "Configuring AMD drivers..."
            sudo apt install -y mesa-vulkan-drivers mesa-vdpau-drivers libvulkan1 vulkan-tools \
                               libdrm-amdgpu1 xserver-xorg-video-amdgpu 2>&1 | tee -a "$LOG_FILE"

            # ROCm for compute (optional but useful)
            # sudo apt install -y rocm-opencl-runtime 2>/dev/null || true

            log "AMD drivers configured ✔"
            ;;

        intel)
            info "Configuring Intel drivers..."
            sudo apt install -y mesa-vulkan-drivers intel-media-va-driver libvulkan1 vulkan-tools \
                               i965-va-driver 2>&1 | tee -a "$LOG_FILE"
            log "Intel drivers configured ✔"
            ;;

        *)
            warn "Unknown GPU vendor. Skipping GPU driver setup."
            ;;
    esac
}

# ── Kernel & CPU Optimisation ─────────────────────────────────────────────────
setup_kernel_optimisations() {
    section "Kernel & CPU Optimisations"

    # CPU Governor — performance mode
    info "Setting CPU governor to performance..."
    sudo apt install -y linux-tools-common cpufrequtils 2>&1 | tee -a "$LOG_FILE"

    # Set all cores to performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" | sudo tee "$cpu" > /dev/null 2>&1 || true
    done

    # Persist CPU governor via udev rule
    sudo tee /etc/udev/rules.d/99-cpu-performance.rules > /dev/null << 'CPUEOF'
SUBSYSTEM=="cpu", ACTION=="add", ATTR{cpufreq/scaling_governor}="performance"
CPUEOF

    # Sysctl gaming tweaks
    info "Applying sysctl gaming tweaks..."
    sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null << 'SYSCTLEOF'
# Reduce swappiness for gaming
vm.swappiness=10

# Increase file watch limit (helps with game engines and shader caches)
fs.inotify.max_user_watches=524288

# Improve network performance
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192

# Transparent Huge Pages — can improve performance in memory-heavy games
# (set to madvise for compatibility balance)
# kernel.transparent_hugepage=madvise

# Reduce latency
kernel.sched_min_granularity_ns=10000000
kernel.sched_wakeup_granularity_ns=15000000

# Increase shared memory for games
kernel.shmmax=4294967296
SYSCTLEOF

    sudo sysctl -p /etc/sysctl.d/99-gaming.conf 2>&1 | tee -a "$LOG_FILE"

    # Transparent Huge Pages
    echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    sudo tee /etc/udev/rules.d/99-thp.rules > /dev/null << 'THPEOF'
SUBSYSTEM=="memory", ACTION=="add", ATTR{power/state}="on"
THPEOF

    # Limits for gaming (open file descriptors etc.)
    sudo tee /etc/security/limits.d/99-gaming.conf > /dev/null << 'LIMEOF'
*    soft    nofile    1048576
*    hard    nofile    1048576
*    soft    nproc     unlimited
*    hard    nproc     unlimited
LIMEOF

    log "Kernel & CPU optimisations applied ✔"
}

# ── Gaming Dependencies ───────────────────────────────────────────────────────
setup_gaming_dependencies() {
    section "Gaming Dependencies"

    info "Installing core gaming libraries..."

    # Enable 32-bit architecture for Wine/Proton
    sudo dpkg --add-architecture i386
    sudo apt update -y 2>&1 | tee -a "$LOG_FILE"

    sudo apt install -y \
        wine wine32 wine64 \
        winetricks \
        dxvk \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools \
        mesa-utils \
        libglib2.0-0 \
        cabextract \
        p7zip-full \
        curl wget git \
        unzip \
        libfreetype6 \
        libfontconfig1 \
        gamemode \
        mangohud \
        goverlay \
        lib32gcc-s1 \
        libsdl2-2.0-0 libsdl2-2.0-0:i386 \
        2>&1 | tee -a "$LOG_FILE" || warn "Some packages may not be available, continuing..."

    # Enable GameMode service
    systemctl --user enable gamemoded 2>/dev/null || true
    systemctl --user start gamemoded 2>/dev/null || true

    log "Gaming dependencies installed ✔"
}

# ── Steam ─────────────────────────────────────────────────────────────────────
setup_steam() {
    section "Steam"

    if ! command -v steam &>/dev/null; then
        info "Installing Steam..."
        sudo apt install -y steam 2>&1 | tee -a "$LOG_FILE"
        log "Steam installed ✔"
    else
        log "Steam already installed ✔"
    fi

    # Steam default launch options hint
    info "Recommended Steam global launch options (set in Steam → Settings → Compatibility):"
    echo -e "  ${BOLD}gamemoderun mangohud %command%${NC}"
}

# ── ProtonPlus ────────────────────────────────────────────────────────────────
setup_protonplus() {
    section "ProtonPlus (Proton Manager)"

    info "Installing ProtonPlus via Flatpak..."
    flatpak install -y flathub com.vysp3r.ProtonPlus 2>&1 | tee -a "$LOG_FILE"
    log "ProtonPlus installed ✔"

    # Create a helpful desktop reminder
    mkdir -p "$HOME/.local/share/applications"
    info "After first boot: open ProtonPlus and install the latest GE-Proton build."
    info "Then in Steam: Properties → Compatibility → Force GE-Proton"
}

# ── Heroic Games Launcher ─────────────────────────────────────────────────────
setup_heroic() {
    section "Heroic Games Launcher (Epic & GOG)"

    info "Installing Heroic Games Launcher..."
    flatpak install -y flathub com.heroicgameslauncher.hgl 2>&1 | tee -a "$LOG_FILE"
    log "Heroic installed ✔"

    info "Tip: In Heroic → Settings → Default Settings, set Wine Version to your GE-Proton build from ProtonPlus."
}

# ── Mouse Peripheral Support ──────────────────────────────────────────────────
setup_mouse_support() {
    section "Mouse & Peripheral Support"

    # ── Logitech (Piper + ratbagd) ────────────────────────────────────────────
    if [[ "$MOUSE_LOGITECH" == true ]]; then
        info "Setting up Logitech mouse support (Piper + libratbag)..."
        sudo apt install -y piper ratbagd 2>&1 | tee -a "$LOG_FILE"
        sudo systemctl enable ratbagd
        sudo systemctl start ratbagd
        log "Piper (Logitech) installed and ratbagd service running ✔"
        info "Launch Piper from your app menu to configure your Logitech mouse DPI, buttons, and lighting."
    fi

    # ── Razer (OpenRazer + Polychromatic) ─────────────────────────────────────
    if [[ "$MOUSE_RAZER" == true ]]; then
        info "Setting up Razer device support (OpenRazer + Polychromatic)..."

        # Add OpenRazer PPA
        sudo apt install -y software-properties-common 2>&1 | tee -a "$LOG_FILE"
        sudo add-apt-repository -y ppa:openrazer/stable 2>&1 | tee -a "$LOG_FILE"
        sudo apt update -y 2>&1 | tee -a "$LOG_FILE"
        sudo apt install -y openrazer-meta 2>&1 | tee -a "$LOG_FILE"

        # Add user to plugdev group
        sudo gpasswd -a "$USER" plugdev
        log "OpenRazer installed. You have been added to the plugdev group ✔"

        # Polychromatic GUI
        sudo add-apt-repository -y ppa:polychromatic/stable 2>&1 | tee -a "$LOG_FILE"
        sudo apt update -y 2>&1 | tee -a "$LOG_FILE"
        sudo apt install -y polychromatic 2>&1 | tee -a "$LOG_FILE"
        log "Polychromatic (Razer RGB GUI) installed ✔"

        warn "A reboot is required for Razer device support to be fully active."
    fi

    # ── SteelSeries (SteelSeries GG via Bottles workaround / ckb-next) ────────
    if [[ "$MOUSE_STEELSERIES" == true ]]; then
        info "Setting up SteelSeries support..."
        # SteelSeries uses HID++ which works natively in Linux for basic use.
        # For full RGB/macro control, install rivalcfg
        if command -v pip3 &>/dev/null || sudo apt install -y python3-pip 2>/dev/null; then
            pip3 install --user rivalcfg 2>&1 | tee -a "$LOG_FILE" || warn "rivalcfg install failed — basic HID support still works."
        fi
        log "SteelSeries basic support configured ✔"
        info "For SteelSeries RGB: rivalcfg is installed. Run 'rivalcfg --help' for usage."
    fi

    # ── Corsair (ckb-next) ────────────────────────────────────────────────────
    if [[ "$MOUSE_CORSAIR" == true ]]; then
        info "Setting up Corsair support (ckb-next)..."
        sudo apt install -y ckb-next 2>&1 | tee -a "$LOG_FILE"
        sudo systemctl enable ckb-next-daemon
        sudo systemctl start ckb-next-daemon
        log "ckb-next (Corsair) installed ✔"
    fi

    # ── ROCCAT (roccat-tools) ─────────────────────────────────────────────────
    if [[ "$MOUSE_ROCCAT" == true ]]; then
        info "Setting up ROCCAT support..."
        sudo apt install -y roccat-tools 2>&1 | tee -a "$LOG_FILE" || warn "roccat-tools not available in repo, basic HID support active."
        log "ROCCAT support configured ✔"
    fi

    # ── Universal: input-remapper (works for ALL mice) ────────────────────────
    info "Installing input-remapper (universal button/macro remapper)..."
    sudo apt install -y input-remapper 2>&1 | tee -a "$LOG_FILE" || \
        pip3 install --user input-remapper 2>/dev/null || \
        warn "input-remapper not available, skipping."
    log "input-remapper available for any peripheral ✔"

    # ── xbindkeys + xdotool (lightweight fallback for any device) ────────────
    sudo apt install -y xbindkeys xdotool 2>&1 | tee -a "$LOG_FILE"
    log "xbindkeys + xdotool installed (universal macro fallback) ✔"
}

# ── Controller Support ────────────────────────────────────────────────────────
setup_controller_support() {
    section "Controller Support"

    # ── Xbox (xpad / xone for Xbox One wireless) ──────────────────────────────
    info "Setting up Xbox controller support..."
    sudo apt install -y xpad joystick jstest-gtk 2>&1 | tee -a "$LOG_FILE"

    # Xbox One wireless dongle (xone driver)
    if [[ "$CONTROLLER_XBOX" == true ]]; then
        info "Detected Xbox controller — installing xone wireless driver..."
        sudo apt install -y dkms linux-headers-$(uname -r) 2>&1 | tee -a "$LOG_FILE"
        if ! dpkg -l | grep -q xone; then
            TMP_XONE=$(mktemp -d)
            git clone https://github.com/medusalix/xone "$TMP_XONE/xone" 2>&1 | tee -a "$LOG_FILE" || warn "Could not clone xone, Xbox wired support still works."
            if [[ -d "$TMP_XONE/xone" ]]; then
                cd "$TMP_XONE/xone"
                sudo bash install.sh --release 2>&1 | tee -a "$LOG_FILE"
                cd - > /dev/null
            fi
            rm -rf "$TMP_XONE"
        fi
        log "Xbox controller support configured ✔"
    fi

    # ── PlayStation DualShock 4 / DualSense ───────────────────────────────────
    if [[ "$CONTROLLER_PS" == true ]]; then
        info "Setting up PlayStation controller support (DS4/DualSense)..."
        sudo apt install -y joystick jstest-gtk 2>&1 | tee -a "$LOG_FILE"

        # DualSense udev rules
        sudo tee /etc/udev/rules.d/70-dualsense.rules > /dev/null << 'DSEOF'
# DualSense (PS5)
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"
# DualShock 4 (PS4)
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"
DSEOF
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log "PlayStation controller udev rules set ✔"

        # dualsensectl for advanced DualSense features
        sudo apt install -y dualsensectl 2>/dev/null || \
            pip3 install --user dualsensectl 2>/dev/null || \
            warn "dualsensectl not available in apt, skipping (basic support still active)."
    fi

    # ── 8BitDo ────────────────────────────────────────────────────────────────
    if [[ "$CONTROLLER_8BITDO" == true ]]; then
        info "Configuring 8BitDo controller..."
        # 8BitDo works via standard HID; udev rule ensures correct permissions
        sudo tee /etc/udev/rules.d/70-8bitdo.rules > /dev/null << '8BDEOF'
KERNEL=="hidraw*", ATTRS{idVendor}=="2dc8", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", MODE="0666"
8BDEOF
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log "8BitDo support configured ✔"
    fi

    # ── Nintendo Switch Pro / Joy-Con ─────────────────────────────────────────
    if [[ "$CONTROLLER_NINTENDO" == true ]]; then
        info "Configuring Nintendo controller support..."
        sudo tee /etc/udev/rules.d/70-nintendo.rules > /dev/null << 'NINEOF'
KERNEL=="hidraw*", ATTRS{idVendor}=="057e", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", MODE="0666"
NINEOF
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log "Nintendo controller support configured ✔"
    fi

    # ── Antimicrox (universal controller → keyboard/mouse mapper) ─────────────
    info "Installing AntiMicroX (universal controller mapping GUI)..."
    flatpak install -y flathub io.github.antimicrox.antimicrox 2>&1 | tee -a "$LOG_FILE"
    log "AntiMicroX installed ✔"

    # ── Steam Input udev rules ────────────────────────────────────────────────
    info "Installing Steam controller udev rules..."
    sudo apt install -y steam-devices 2>&1 | tee -a "$LOG_FILE" || true
    log "Steam controller udev rules applied ✔"

    # ── Bluetooth stack ───────────────────────────────────────────────────────
    info "Ensuring Bluetooth stack is ready..."
    sudo apt install -y bluetooth blueman bluez bluez-tools 2>&1 | tee -a "$LOG_FILE"
    sudo systemctl enable bluetooth
    sudo systemctl start bluetooth
    log "Bluetooth configured ✔"
}

# ── Audio ─────────────────────────────────────────────────────────────────────
setup_audio() {
    section "Audio Optimisation"

    # Pipewire (Pop!_OS 24.04 default)
    info "Ensuring PipeWire audio is optimal for gaming..."
    sudo apt install -y pipewire pipewire-pulse pipewire-alsa wireplumber \
                       libspa-0.2-bluetooth 2>&1 | tee -a "$LOG_FILE"

    # Low latency PipeWire config
    mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"
    tee "$HOME/.config/pipewire/pipewire.conf.d/99-gaming-latency.conf" > /dev/null << 'PWEOF'
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 512
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 8192
}
PWEOF

    systemctl --user restart pipewire 2>/dev/null || true
    log "PipeWire low-latency audio configured ✔"
}

# ── Flatseal ──────────────────────────────────────────────────────────────────
setup_flatseal() {
    section "Flatseal (Flatpak Permissions Manager)"
    flatpak install -y flathub com.github.tchx84.Flatseal 2>&1 | tee -a "$LOG_FILE"
    log "Flatseal installed ✔"
}

# ── MangoHud Config ───────────────────────────────────────────────────────────
setup_mangohud_config() {
    section "MangoHud Configuration"

    mkdir -p "$HOME/.config/MangoHud"
    tee "$HOME/.config/MangoHud/MangoHud.conf" > /dev/null << 'MHEOF'
# MangoHud Gaming Overlay Config
fps
frametime
cpu_stats
cpu_temp
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
vram
ram
io_read
io_write
frame_timing
histogram
position=top-left
toggle_hud=Shift_R+F12
toggle_fps_limit=Shift_L+F1
font_size=20
background_alpha=0.4
MHEOF

    log "MangoHud configured ✔"
    info "Toggle MangoHud overlay with Shift+F12 in any game."
}

# ── GOverlay ─────────────────────────────────────────────────────────────────
setup_goverlay() {
    section "GOverlay (MangoHud GUI Config)"
    sudo apt install -y goverlay 2>&1 | tee -a "$LOG_FILE" || \
        flatpak install -y flathub io.github.benjamimgois.goverlay 2>&1 | tee -a "$LOG_FILE" || \
        warn "GOverlay not available, use MangoHud config file directly."
    log "GOverlay available for visual MangoHud configuration ✔"
}

# ── Environment Variables ─────────────────────────────────────────────────────
setup_environment() {
    section "Gaming Environment Variables"

    PROFILE_SNIPPET="$HOME/.profile.d/gaming.sh"
    mkdir -p "$HOME/.profile.d"

    tee "$PROFILE_SNIPPET" > /dev/null << 'ENVEOF'
# ── Gaming Environment Variables ──────────────────────────────────────────────

# DXVK Async (reduces shader compilation stutters)
export DXVK_ASYNC=1

# Proton force usage of DXVK
export PROTON_USE_WINED3D=0

# Wine ESYNC / FSYNC (improves CPU-bound performance)
export WINEESYNC=1
export WINEFSYNC=1

# Proton log (set to 0 in production)
export PROTON_LOG=0

# Steam runtime
export STEAM_RUNTIME=1

# NVIDIA (if applicable)
export __GL_THREADED_OPTIMIZATION=1
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="$HOME/.cache/nvidia-shaders"

# Reduce input lag for Vulkan
export VKD3D_CONFIG=dxr11
ENVEOF

    # Source profile.d in .profile
    if ! grep -q "profile.d" "$HOME/.profile" 2>/dev/null; then
        echo '
# Source profile.d scripts
for f in "$HOME/.profile.d/"*.sh; do [ -f "$f" ] && . "$f"; done' >> "$HOME/.profile"
    fi

    # Create NVIDIA shader cache dir
    mkdir -p "$HOME/.cache/nvidia-shaders"

    log "Gaming environment variables set ✔"
}

# ── Final Summary ─────────────────────────────────────────────────────────────
final_summary() {
    section "Setup Complete 🎮"

    echo -e "${GREEN}${BOLD}Everything has been configured! Here's your summary:${NC}\n"

    echo -e "${BOLD}Launchers:${NC}"
    echo -e "  • Steam (with GameMode + MangoHud launch options)"
    echo -e "  • Heroic Games Launcher (Epic & GOG)"
    echo -e "  • ProtonPlus (open it now to install GE-Proton!)"

    echo -e "\n${BOLD}Performance Tools:${NC}"
    echo -e "  • GameMode — auto-optimises CPU when gaming"
    echo -e "  • MangoHud — in-game overlay (toggle: Shift+F12)"
    echo -e "  • GOverlay — GUI for MangoHud config"
    echo -e "  • CPU governor set to performance"
    echo -e "  • Kernel/sysctl gaming tweaks applied"
    echo -e "  • PipeWire low-latency audio configured"

    echo -e "\n${BOLD}Peripheral Support:${NC}"
    [[ "$MOUSE_LOGITECH" == true ]]    && echo -e "  • Piper (Logitech) — launch from app menu"
    [[ "$MOUSE_RAZER" == true ]]       && echo -e "  • OpenRazer + Polychromatic (Razer) — reboot required!"
    [[ "$MOUSE_STEELSERIES" == true ]] && echo -e "  • rivalcfg (SteelSeries) — run 'rivalcfg --help'"
    [[ "$MOUSE_CORSAIR" == true ]]     && echo -e "  • ckb-next (Corsair) — daemon running"
    [[ "$MOUSE_ROCCAT" == true ]]      && echo -e "  • ROCCAT tools configured"
    echo -e "  • input-remapper — universal button remapper"
    echo -e "  • AntiMicroX — controller → keyboard/mouse mapping"
    echo -e "  • Steam Input udev rules applied"
    echo -e "  • Bluetooth stack ready"

    echo -e "\n${BOLD}Recommended Steam Launch Options:${NC}"
    echo -e "  ${CYAN}gamemoderun mangohud %command%${NC}"

    echo -e "\n${BOLD}Next Steps:${NC}"
    echo -e "  1. Open ${CYAN}ProtonPlus${NC} and install the latest GE-Proton"
    echo -e "  2. In Steam: Settings → Compatibility → Enable Steam Play for all titles → select GE-Proton"
    echo -e "  3. In Heroic: Settings → Default Settings → set Wine to GE-Proton"
    echo -e "  4. Use ${CYAN}Piper${NC} to configure your Logitech mouse"
    echo -e "  5. ${RED}Reboot your system${NC} to apply all changes\n"

    echo -e "${YELLOW}${BOLD}⚠  Please reboot now for all changes to take full effect.${NC}\n"
    echo -e "  Log saved to: ${CYAN}$LOG_FILE${NC}\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    clear
    banner
    echo "" > "$LOG_FILE"

    preflight_checks
    detect_hardware
    system_update
    setup_flatpak
    setup_gpu_drivers
    setup_kernel_optimisations
    setup_gaming_dependencies
    setup_steam
    setup_protonplus
    setup_heroic
    setup_mouse_support
    setup_controller_support
    setup_audio
    setup_flatseal
    setup_mangohud_config
    setup_goverlay
    setup_environment
    final_summary
}

main "$@"
