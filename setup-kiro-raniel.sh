#!/usr/bin/env bash
set -e

# ============================================================
#  KIRO RANIEL ISO – Complete Setup Script
#  Hyprland + Niri + DankMaterialShell + KIRO RANIEL branding
#  Run from inside your forked kiro-iso folder
# ============================================================

UPSTREAM_URL="https://github.com/kirodubes/kiro-iso.git"
UPSTREAM_BRANCH=$(git ls-remote --symref "$UPSTREAM_URL" HEAD 2>/dev/null | awk '/^ref:/ {sub(/refs\/heads\//, "", $2); print $2; exit}')
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
TODAY=$(date +%Y%m)
VERSION=$(date +%Y.%m.%d)

echo "=============================================="
echo "  🔧 KIRO RANIEL ISO SETUP"
echo "=============================================="

# ============================================
#  STEP 1 – Sync with upstream
# ============================================
echo ""
echo "[1/6] 🔄 Syncing with upstream ($UPSTREAM_URL)..."
if ! git remote get-url upstream &>/dev/null; then
    git remote add upstream "$UPSTREAM_URL"
fi
git fetch upstream
CURRENT_BRANCH=$(git branch --show-current)
echo "      📂 Current branch: $CURRENT_BRANCH"
echo "      ⬇️  Merging upstream/$UPSTREAM_BRANCH..."
if git merge "upstream/$UPSTREAM_BRANCH" -m "Merge upstream changes"; then
    echo "      ✅ Upstream merged successfully."
else
    echo "      ⚠️  Merge conflicts detected! Resolve them, then re-run this script."
    exit 1
fi

# ============================================
#  STEP 2 – Create directory structure
# ============================================
echo ""
echo "[2/6] 📁 Creating directory tree..."
mkdir -p archiso/airootfs/etc/skel/.config/{hypr,niri,dms}
mkdir -p archiso/airootfs/root
mkdir -p out
echo "      ✅ Directories ready."

# ============================================
#  STEP 3 – Write packages.x86_64
# ============================================
echo ""
echo "[3/6] 📦 Updating package list..."
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
echo "      ✅ Packages written."

# ============================================
#  STEP 4 – Write all config files
# ============================================
echo ""
echo "[4/6] ⚙️  Creating config files..."

# Hyprland
cat > archiso/airootfs/etc/skel/.config/hypr/hyprland.conf << 'HYPRCONF'
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
echo "      ✅ Hyprland config."

# Niri
cat > archiso/airootfs/etc/skel/.config/niri/config.kdl << 'NIRICONF'
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
echo "      ✅ Niri config."

# DMS config
cat > archiso/airootfs/etc/skel/.config/dms/config.ron << 'DMSCONF'
(
    gaps: 6,
    border_width: 2,
    focus_follows_mouse: true,
    default_layout: "dwindle",
)
DMSCONF
echo "      ✅ DMS config."

# DMS installer (runs during ISO build)
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
echo "      ✅ DMS installer script."

# ============================================
#  STEP 5 – Branding: KIRO RANIEL in profiledef.sh
# ============================================
echo ""
echo "[5/6] 🏷️  Applying KIRO RANIEL branding..."

PROFILE_FILE="archiso/profiledef.sh"

# If missing, create minimal profiledef.sh
if [ ! -f "$PROFILE_FILE" ]; then
    echo "      ⚠️  profiledef.sh not found, creating it..."
    cat > "$PROFILE_FILE" << PROFILEHEAD
#!/usr/bin/env bash
iso_name="kiro-iso"
iso_label="KIRO_RANIEL_${TODAY}"
iso_publisher="KIRO RANIEL"
iso_application="KIRO RANIEL Live ISO"
iso_version="${VERSION}"
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
)
PROFILEHEAD
else
    # Update branding variables in place
    sed -i "s|^iso_label=.*|iso_label=\"KIRO_RANIEL_${TODAY}\"|" "$PROFILE_FILE"
    sed -i 's|^iso_publisher=.*|iso_publisher="KIRO RANIEL"|' "$PROFILE_FILE"
    sed -i 's|^iso_application=.*|iso_application="KIRO RANIEL Live ISO"|' "$PROFILE_FILE"
    sed -i "s|^iso_version=.*|iso_version=\"${VERSION}\"|" "$PROFILE_FILE"
fi

# Ensure customize_airootfs hook exists
if ! grep -q "customize_airootfs()" "$PROFILE_FILE"; then
    cat >> "$PROFILE_FILE" << 'PROFILEHOOK'

customize_airootfs() {
    echo "==> Running DMS and custom setup..."
    bash /root/customize_install.sh
}
PROFILEHOOK
fi

echo "      ✅ Branding applied: KIRO RANIEL"

# ============================================
#  STEP 6 – Commit & push to GitHub
# ============================================
echo ""
echo "[6/6] 📤 Committing and pushing to GitHub..."
git add -A
if git diff --cached --quiet; then
    echo "      ℹ️  Nothing to commit."
else
    git commit -m "KIRO RANIEL: Hyprland + Niri + DMS + branding (automated)"
fi

echo "      🚀 Pushing to origin/$CURRENT_BRANCH..."
git push origin "$CURRENT_BRANCH"
echo "      ✅ Pushed successfully!"

# ============================================
#  DONE – Summary
# ============================================
echo ""
echo "=============================================="
echo "  ✅ KIRO RANIEL SETUP COMPLETE"
echo "=============================================="
echo ""
echo "  📀 ISO Label:   KIRO_RANIEL_${TODAY}"
echo "  🏷️  Publisher:  KIRO RANIEL"
echo "  🖥️  Compositors: Hyprland + Niri"
echo "  🐚 Shell:       DankMaterialShell (DMS)"
echo "  🌿 Branch:      $CURRENT_BRANCH"
echo ""
echo "  👉 Build the ISO:  sudo mkarchiso -v ./archiso"
echo "=============================================="