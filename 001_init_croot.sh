#!/usr/bin/env bash
set -euo pipefail

#### AJUSTA ESTAS VARIABLES ####
DISK="/dev/sda"                 # Disco donde instalar
EFI_PART="${DISK}1"             # Partición EFI (FAT32)
ROOT_PART="${DISK}2"            # Partición raíz (ext4)
HOSTNAME="wolf"                 # Nombre de tu equipo
USERNAME="usuario"              # Nombre del usuario a crear
ROOTPASS="changeme"             # Contraseña de root
USERPASS="changeme"             # Contraseña del usuario
TIMEZONE="America/Guayaquil"
LOCALE="en_US.UTF-8"
################################

echo "==> 1) FORMATEO Y MONTAJE"
mkfs.ext4 "$ROOT_PART"
mkfs.fat -F32 "$EFI_PART"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

echo "==> 2) INSTALACIÓN BASE"
pacstrap /mnt \
  base linux linux-firmware base-devel efibootmgr os-prober \
  networkmanager grub gvfs nano netctl wpa_supplicant dialog \
  xf86-input-synaptics udisks2 ntfs-3g bash-completion

echo "==> 3) GENERAR fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "==> 4) CHROOT & CONFIGURACIÓN COMPLETA"
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Zona horaria y reloj
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc --utc

# Locales
sed -i "s|#\s*\($LOCALE UTF-8\)|\1|" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=en"    > /etc/vconsole.conf

# Hostname y hosts
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<H
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localhost $HOSTNAME
H

# Sincronización NTP
sed -i '/^#NTP=/d' /etc/systemd/timesyncd.conf
sed -i 's/^#Fallback/Fallback/' /etc/systemd/timesyncd.conf
echo "FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 0.fr.pool.ntp.org" \
  >> /etc/systemd/timesyncd.conf
systemctl enable systemd-timesyncd

# Contraseñas
echo "root:$ROOTPASS" | chpasswd

# Crear usuario y sudo
useradd -m -G wheel,audio,video,storage -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
pacman -S --noconfirm sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# NetworkManager
systemctl enable NetworkManager

# Instalar y configurar GRUB con soporte Windows
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
             --bootloader-id="Arch Linux"
sed -i '/^GRUB_DISABLE_OS_PROBER=/d' /etc/default/grub
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
os-prober
grub-mkconfig -o /boot/grub/grub.cfg

# Instalar entorno gráfico y Qtile
pacman -S --noconfirm \
  xorg-server xorg-xinit xorg-xinput xf86-video-nouveau \
  mesa mesa-libgl libvdpau-va-gl xf86-input-libinput \
  python python-pip qtile lightdm lightdm-gtk-greeter \
  alacritty zip unzip curl unrar git firefox opera \
  opera-ffmpeg-codecs rofi lsd bat wget

# Fuentes opcionales
pacman -S --noconfirm \
  ttf-ubuntu-font-family noto-fonts ttf-dejavu \
  ttf-liberation ttf-bitstream-vera

# Habilitar LightDM
systemctl enable lightdm

# Limpieza
pacman -Scc --noconfirm

EOF

echo "==> 5) DESMONTAJE y REINICIO"
umount -R /mnt
echo "Listo: quita el USB y reinicia para arrancar tu nuevo sistema."
