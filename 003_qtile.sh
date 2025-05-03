#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------
# Configura esto si tu usuario no es $USER
USER_NAME="${USER}"
HOME_DIR="/home/${USER_NAME}"
AUR_HELPER="paru"   # cambiable a "yay" si prefieres
# --------------------------------------------------------

echo -e "\n==> 1) Instalar apps básicas de brillo, ventanas y AUR helper\n"
sudo pacman -S --noconfirm brightnessctl redshift \
    picom feh exa udiskie arandr imv flameshot pcmanfm \
    network-manager-applet cbatticon notification-daemon \
    libnotify volumeicon xcb-util-cursor gcc nodejs npm \
    zsh zsh-completions lsd bat

# Instalar paru (AUR helper)
echo -e "\n==> 2) Instalando ${AUR_HELPER} (AUR helper)\n"
cd /tmp
git clone https://aur.archlinux.org/paru.git
sudo chown -R "${USER_NAME}:${USER_NAME}" paru
cd paru
makepkg -si --noconfirm
cd ..
rm -rf paru

echo -e "\n==> 3) Instalar paquetes de AUR con ${AUR_HELPER}\n"
${AUR_HELPER} -S --noconfirm ccat lightdm-webkit2-greeter \
  lightdm-webkit-theme-aether

echo -e "\n==> 4) Configurar LightDM webkit2-greeter\n"
sudo sed -i 's/^#\?greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' \
    /etc/lightdm/lightdm.conf
sudo systemctl enable lightdm

echo -e "\n==> 5) Instalar ícono de volumen en autostart de Qtile\n"
AUTOSTART="${HOME_DIR}/.config/qtile/autostart.sh"
mkdir -p "$(dirname "$AUTOSTART")"
grep -q volumeicon "$AUTOSTART" 2>/dev/null || cat >> "$AUTOSTART" <<EOF

# Volume icon
volumeicon &
EOF
chmod u+x "$AUTOSTART"

echo -e "\n==> 6) Configurar udiskie para icono USB\n"
grep -q udiskie "$AUTOSTART" 2>/dev/null || cat >> "$AUTOSTART" <<EOF

# USB automount icon
udiskie -t &
EOF

echo -e "\n==> 7) Instalar temas GTK & cursor (manual)\n"
echo " * Descarga Material-Black-Blueberry y descomprime:"
echo "   wget -O /tmp/Material-Black-Blueberry.zip https://www.gnome-look.org/p/1316887/startdownload?file_id=XXXX"
echo "   unzip /tmp/Material-Black-Blueberry.zip -d /tmp"
echo "   sudo mv /tmp/Material-Black-Blueberry /usr/share/themes/"
echo
echo " * Descarga Material-Black-Blueberry-Suru y Cursor Breeze igual en /usr/share/icons/"
echo
echo " * Luego ejecuta:"
echo "   sudo pacman -S --noconfirm lxappearance"
echo "   lxappearance"
echo

echo -e "\n==> 8) Ajustar servicio de notificaciones D-Bus\n"
sudo sed -i 's|^Exec=.*|Exec=/usr/lib/notification-daemon-1.0/notification-daemon|' \
    /usr/share/dbus-1/services/org.freedesktop.Notifications.service

echo -e "\n==> 9) Prueba de notificaciones\n"
notify-send "Setup Apps" "Notificaciones listas ✅"

echo -e "\n==> 10) Instalar Oh My Zsh y plugins\n"
if [ ! -d "${HOME_DIR}/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="${HOME_DIR}/.oh-my-zsh/custom"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "${ZSH_CUSTOM}/themes/powerlevel10k" || true
git clone https://github.com/zsh-users/zsh-autosuggestions.git \
    "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" || true

# Ajustes en .zshrc
ZSHRC="${HOME_DIR}/.zshrc"
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC"
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting sudo)/' "$ZSHRC"
grep -q ENABLE_CORRECTION "$ZSHRC" || echo 'ENABLE_CORRECTION="true"' >> "$ZSHRC"

echo -e "\n==> 11) Instalar psutil y pipenv en user\n"
pip install --user psutil pipenv

echo -e "\n==> 12) ¡Listo! Cierra sesión o reinicia para aplicar todos los cambios.\n"
