#!/bin/bash
set -e
echo "==> Building DankMaterialShell from source..."
git clone https://github.com/avengemedia/dms.git /tmp/dms
cd /tmp/dms
makepkg -si --noconfirm
cd /
rm -rf /tmp/dms
echo "==> DMS installation complete."
