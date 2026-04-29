#!/usr/bin/env bash
set -e

# ============================================================
#  KIRO-ISO: Add Hyprland, Niri & DankMaterialShell support
#  Run from inside your forked kiro-iso folder
# ============================================================

UPSTREAM_URL="https://github.com/kirodubes/kiro-iso.git"
UPSTREAM_BRANCH=$(git ls-remote --symref "$UPSTREAM_URL" HEAD 2>/dev/null | awk '/^ref:/ {sub(/refs\/heads\//, "", $2); print $2; exit}')
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"

echo "=============================================="
echo "  KIRO-ISO CUSTOM SETUP SCRIPT"
echo "=============================================="

# --- Step 1: Sync with upstream ---
echo ""
echo "[1/5] Syncing with upstream ($UPSTREAM_URL)..."
if ! git remote get-url upstream &>/dev/null; then
    git remote add upstream "$UPSTREAM_URL"
fi
git fetch upstream
CURRENT_BRANCH=$(git branch --show-current)
echo "      Current branch: $CURRENT_BRANCH"
echo "      Merging upstream/$UPSTREAM_BRANCH..."
if git merge "upstream/$UPSTREAM_BRANCH" -m "Merge upstream changes"; then
    echo "      ✅ Upstream merged successfully."
else
    echo "      ⚠️ Merge conflicts detected! Resolve them, then re-run this script."
    exit 1
fi

# --- Step 2: Create all directories ---
echo ""
echo "[2/5] Creating directory structure..."
mkdir -p archiso/airootfs/etc/skel/.config/{hypr,niri,dms}
mkdir -p archiso/airootfs/root
echo "      ✅ Directories ready."

# --- Step 3: Overwrite packages.x86_64 ---
echo ""
echo "[3/5] Updating package list (archiso/packages.x86_64)..."
cat > archiso/packages.x86_64 << 'PACKAGES'
# --- Wayland base ---
wayland
wayland-protocols
pipewire
wireplumber
lib32-pipewire
xdg-desktop-portal
xdg-desktop-portal-gtk

# --- Compositors ---
hyprland
niri
xdg-desktop-portal-hyprland

# --- DMS build dependencies ---
scdoc
meson
ninja
cargo
just
git

# --- Core applications ---
kitty
wofi
waybar
network-manager-applet
brightnessctl
pamixer
grim
slurp
swappy
wl-clipboard

# --- Fonts & theming ---
ttf-jetbrains-mono
ttf-font-awesome
papirus-icon-theme

# --- Utilities ---
polkit-gnome
PACKAGES
echo "      ✅ Packages updated."

# --- Step 4: Create all config files ---
echo ""
echo "[4/5] Writing configuration files..."

# Hyprland config
cat > archiso/airootfs/etc/skel/.config/hypr/hyprland.conf << 'HYPRCONF'
# --- Hyprland minimal config ---
monitor=,preferred,auto,1

exec-once = waybar &
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
exec-once = nm-applet &
exec-once = wireplumber
exec-once = pipewire

bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, F, fullscreen,
bind = SUPER, Space, exec, wofi --show drun
HYPRCONF
echo "      ✅ Hyprland config written."

# Niri config
cat > archiso/airootfs/etc/skel/.config/niri/config.kdl << 'NIRICONF'
// --- Niri minimal config + DMS launch ---
input {
    keyboard {
        xkb_layout "us"
    }
}

spawn-at-startup "waybar"
spawn-at-startup "nm-applet"
spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
spawn-at-startup "dms"

binds {
    Mod+Return { spawn "kitty"; }
    Mod+Q { close-window; }
    Mod+Space { spawn "wofi --show drun"; }
}
NIRICONF
echo "      ✅ Niri config written."

# DMS config
cat > archiso/airootfs/etc/skel/.config/dms/config.ron << 'DMSCONF'
(
    gaps: 6,
    border_width: 2,
    focus_follows_mouse: true,
    default_layout: "dwindle",
)
DMSCONF
echo "      ✅ DMS config written."

# DMS build script (runs during ISO creation)
cat > archiso/airootfs/root/customize_install.sh << 'DMSSETUP'
#!/bin/bash
set -e

echo "==> Building DankMaterialShell from source..."
git clone https://github.com/avengemedia/dms.git /tmp/dms
cd /tmp/dms
makepkg -si --noconfirm
cd /
rm -rf /tmp/dms
echo "==> DMS installation complete."
DMSSETUP
chmod +x archiso/airootfs/root/customize_install.sh
echo "      ✅ DMS installer script written."

# --- Step 5: Update profiledef.sh ---
echo ""
echo "[5/5] Updating profiledef.sh..."

PROFILE_FILE="archiso/profiledef.sh"

# If profiledef.sh doesn't exist, create a minimal one
if [ ! -f "$PROFILE_FILE" ]; then
    echo "      ⚠️ profiledef.sh not found, creating new one..."
    cat > "$PROFILE_FILE" << 'PROFILEHEAD'
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="kiro-iso"
iso_label="KIRO_$(date +%Y%m)"
iso_publisher="KIRO"
iso_application="KIRO Live ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.grub.esp' 'uefi-x64.grub.esp'
           'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/customize_install.sh"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
PROFILEHEAD
fi

# Check if customize_airootfs function already exists
if grep -q "customize_airootfs()" "$PROFILE_FILE"; then
    echo "      ⚠️ customize_airootfs() already exists. Skipping."
    echo "      👉 Manually ensure it calls: bash /root/customize_install.sh"
else
    # Append the function before any existing trailing content
    cat >> "$PROFILE_FILE" << 'PROFILEHOOK'

customize_airootfs() {
    echo "==> Running DMS and custom setup..."
    bash /root/customize_install.sh
}
PROFILEHOOK
    echo "      ✅ profiledef.sh updated with customize hook."
fi

# --- Final commit ---
echo ""
echo "=============================================="
echo "  ✅ ALL FILES CREATED SUCCESSFULLY!"
echo "=============================================="
echo ""
echo "Committing changes to branch: $CURRENT_BRANCH"
git add -A
git commit -m "Add Hyprland, Niri, and DankMaterialShell support (automated setup)" || echo "      (nothing to commit or already committed)"

read -p "Push to your GitHub fork? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin "$CURRENT_BRANCH"
    echo "🚀 Pushed to GitHub!"
else
    echo "ℹ️ Skipped push. You can push later with: git push origin $CURRENT_BRANCH"
fi

echo ""
echo "=============================================="
echo "  NEXT STEP: Build the ISO"
echo "  Run: sudo mkarchiso -v ./archiso"
echo "=============================================="