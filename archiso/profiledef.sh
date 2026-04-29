#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="kiro"
iso_label="KIRO_RANIEL_202604"
iso_publisher="KIRO RANIEL"
iso_application="KIRO RANIEL Live ISO"
iso_version="2026.04.29"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
#airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86')
#airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
#airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6')
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')
bootstrap_tarball_compression=(zstd -19)
file_permissions=(
  ["/etc/gshadow"]="0:0:400"
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/grub.d/40_custom"]="0:0:755"
)

customize_airootfs() {
    echo "==> Running DMS and custom setup..."
    bash /root/customize_install.sh
}
