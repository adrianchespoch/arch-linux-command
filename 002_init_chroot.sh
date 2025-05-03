#!/usr/bin/env bash
set -euo pipefail

echo
echo "==> 1) Asegurando que NetworkManager esté activo..."
sudo systemctl start NetworkManager.service
sudo systemctl enable NetworkManager.service

echo
echo "==> 2) Conectarse a Wi-Fi"
read -rp "SSID: " SSID
read -rsp "Password: " WIFI_PASS && echo
echo "Conectando a $SSID..."
sudo nmcli device wifi connect "$SSID" password "$WIFI_PASS"

echo
echo "==> 3) Comprobando conexión..."
ping -c 3 archlinux.org

echo
echo "==> 4) Actualizando sistema e instalando Qtile + entorno gráfico"
sudo pacman -Syu --noconfirm

sudo pacman -S --noconfirm \
  xorg-server xorg-xinit xorg-xinput xf86-video-nouveau \
  mesa mesa-libgl libvdpau-va-gl xf86-input-libinput \
  python python-pip qtile lightdm lightdm-gtk-greeter \
  alacritty zip unzip curl unrar git firefox opera \
  opera-ffmpeg-codecs rofi lsd bat wget

echo
read -rp "¿Instalar fuentes opcionales (Ubuntu, Noto, DejaVu, Liberation, Bitstream)? [Y/n] " RESP
if [[ "$RESP" =~ ^[Yy]?$ ]]; then
  sudo pacman -S --noconfirm \
    ttf-ubuntu-font-family noto-fonts ttf-dejavu \
    ttf-liberation ttf-bitstream-vera
fi

echo
echo "==> 5) Habilitar LightDM"
sudo systemctl enable lightdm.service

echo
echo "==> 6) Limpiar caché de paquetes"
yes | sudo pacman -Scc

echo
read -rp "¿Reiniciar ahora? [Y/n] " REBOOT
if [[ "$REBOOT" =~ ^[Yy]?$ ]]; then
  echo "Reiniciando..."
  sudo reboot
else
  echo "Hecho. Puedes reiniciar cuando quieras."
fi
