#!/usr/bin/env bash
set -euo pipefail

echo "Desinstalando CastoPOST..."

sudo rm -f /usr/local/bin/castopost-bin
sudo rm -f /usr/local/bin/castopost
rm -f "${HOME}/.local/share/applications/castopost.desktop"
rm -f "${HOME}/.local/share/icons/hicolor/scalable/apps/castopost.svg"
update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

echo "✓ CastoPOST desinstalado."
echo ""
echo "Los datos de usuario NO se han eliminado. Si quieres borrarlos:"
echo "  rm -rf ~/.config/castopost ~/.local/share/castopost"
