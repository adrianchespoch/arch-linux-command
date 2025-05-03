#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------
# 1) Pedir variables al usuario
read -rp "Hostname (p.ej. wolf): " HOSTNAME
read -rp "Nombre de usuario (p.ej. usuario): " USERNAME
read -rsp "Contraseña de root: " ROOTPASS && echo
read -rsp "Contraseña de ${USERNAME}: " USERPASS && echo
TIMEZONE="America/Guayaquil"
LOCALE="en_US.UTF-8"
# -----------------------------------

echo
echo "==> 1) Sincronizando reloj..."
timedatectl set-ntp true

echo
echo "==> 2) Asegúrate de que hayas montado manualmente tus particiones:"
echo "   • /mnt          → raíz"
echo "   • /mnt/home     → /home (si aplica)"
echo "   • /mnt/boot     → /boot o /mnt/boot/efi"
read -rp "Presiona [ENTER] cuando estén montadas y quieras continuar…"

echo
echo "==> 3) Instalando base y herramientas…"
pacstrap /mnt \
  base linux linux-firmware base-devel efibootmgr os-prober \
  networkmanager grub gvfs nano netctl wpa_supplicant dialog \
  xf86-input-synaptics udisks2 ntfs-3g bash-completion

echo
echo "==> 4) Generando /etc/fstab…"
genfstab -U /mnt >> /mnt/etc/fstab

echo
echo "==> 5) Entrando en chroot y configurando sistema…"
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Zona horaria y reloj
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc --utc

# Locales
sed -i "s|#\s*\($LOCALE UTF-8\)|\1|" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE"    > /etc/locale.conf
echo "KEYMAP=en"       > /etc/vconsole.conf

# Hostname y hosts
echo "$HOSTNAME"       > /etc/hostname
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
useradd -m -G wheel,audio,video,storage -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

# Sudoers
pacman -S --noconfirm sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# NetworkManager
systemctl enable NetworkManager

# GRUB + os-prober
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
             --bootloader-id="Arch Linux"
sed -i '/^GRUB_DISABLE_OS_PROBER=/d' /etc/default/grub
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
os-prober
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo
echo "==> 6) Desmontando y listo para reiniciar…"
umount -R /mnt

cat <<MSG

✅ Instalación completada.
   Retira el USB y reinicia tu máquina.

MSG
