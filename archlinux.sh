#!/usr/bin/env bash
echo ""
echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

timedatectl set-ntp true

echo ""
echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo ""
# Display available disks for the user to choose
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ): "
read DISK
# Manual partitioning
echo "Manual Partitioning..."
cfdisk "$DISK"
echo "="
echo "Please Enter EFI Paritition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ): "
read EFI
echo "="
echo "Please Enter Root Paritition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ): "
read ROOT
echo "="
echo "Please Enter Your hostname: "
read HOSTNAME
echo "="
echo "Please Enter Your hostname password: "
read HOSTNAMEPASSWORD
echo "="
echo "Please Enter Your username: "
read USERNAME
echo "="
echo "Please Enter Your username password: "
read USERNAMEPASSWORD
echo "="
echo "Enter Your Locale ( Example: en_US.UTF-8 ): "
read LOCALE
echo "="
echo "Enter Your Keyboard Layout ( Example: us ): "
read KEYBOARD_LAYOUT
echo "="
echo "Please Chosse The Kernel: "
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "Please Choose Your Desktop Environment: "
echo "1. CINNAMON"
echo "2. GNOME"
echo "3. KDE"
echo "4. No Desktop"
read DESKTOP
echo "="
echo "Please Choose Your Graphic Card: "
echo "1. for AMD"
echo "2. foe INTEL"
echo "3. for AMD and NVIDIA"
echo "4. for INTEL and NVIDIA"
read GRAPHIC
echo "="
echo "Do You Want To Install Office: "
echo "1. for WPS-Office"
echo "2. for OnlyOffice"
echo "3. for LibreOffice"
echo "4. I Don't want To Install"
echo "="
read OFFICE
echo "="
echo "Will you Gaming: "
echo "1. for Yes"
echo "2. for No"
read GAME
echo "="
echo "Do You Want To Install Virtualbox: "
echo "1. for Yes"
echo "2. for No"
read VIRTUALBOX
echo "="
echo "================================================================="
echo "==                      Format And Mount                       =="
echo "================================================================="

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
mkfs.ext4 -L "ROOT" "${ROOT}"

mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount -t vfat "${EFI}" /mnt/boot/

echo "================================================================="
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [ $KERNEL == "1" ]
then
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers nano amd-ucode grub efibootmgr git wget reflector rsync networkmanager wireless_tools mtools net-tools dosfstools openssh
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers nano amd-ucode grub efibootmgr git wget reflector rsync networkmanager wireless_tools mtools net-tools dosfstools openssh
fi

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
echo "$HOSTNAME:$HOSTNAMEPASSWORD" | chpasswd
useradd -mG wheel $USERNAME
echo "$USERNAME:$USERNAMEPASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "================================================================="
echo "==                 Setup Language and Set Locale               =="
echo "================================================================="

sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
echo "LANG=$LOCALE" >> /etc/locale.conf
echo "KEYMAP=$KEYBOARD_LAYOUT" >> /etc/vconsole.conf
locale-gen

ln -sf /usr/share/zoneinfo/$(timedatectl | awk '/Time zone/ {print $3}') /etc/localtime
hwclock --systohc

echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF

echo "================================================================="
echo "==                     Installing Grub                         =="
echo "================================================================="

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash udev.log_priority=3"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "================================================================="
echo "==                    Enable Multilib Repo                     =="
echo "================================================================="

pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "/Color/a ILoveCandy" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 4/" /etc/pacman.conf

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf
pacman -Sy pamac-aur brave-bin optimus-manager optimus-manager-qt auto-cpufreq mailspring figma-linux --noconfirm --needed

sed -i "s/^#EnableAUR/EnableAUR/" /etc/pamac.conf
pamac update all --noconfirm --needed

echo "================================================================="
echo "==        Installing Audio, Printer, Bluetooth Drivers         =="
echo "================================================================="

pacman -S xf86-input-libinput libinput touchegg bash-completion bluez bluez-utils cups pipewire pipewire-audio pipewire-alsa pipewire-jack pipewire-pulse libpipewire downgrade --noconfirm --needed

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups
systemctl enable touchegg
systemctl enable sshd
systemctl enable fstrim.timer
systemctl enable optimus-manager
systemctl enable auto-cpufreq

#DESKTOP ENVIRONMENT
if [ $DESKTOP == "1" ]
then
    pacman -S cinnamon nemo nemo-fileroller xed gnome-terminal fish gnome-themes-extra gnome-keyring system-config-printer lightdm lightdm-slick-greeter xdg-user-dirs-gtk blueman numlockx exfatprogs f2fs-tools traceroute cronie gufw xdg-desktop-portal-gtk gnome-system-monitor gnome-screenshot transmission-gtk gnome-calculator gnome-calendar simple-scan kdenlive mediainfo shotwell snapshot gimp xournalpp redshift openvpn networkmanager-openvpn ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster audacity audacious celluloid mplayer bookworm obs-studio gparted ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 nodejs npm python-pip pyenv postgresql mariadb android-tools vala tk kvantum-git mint-themes filezilla --noconfirm --needed
    systemctl enable lightdm
    sed -i "s/^#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/" /etc/lightdm/lightdm.conf
elif [ $DESKTOP == "2" ]
then
    pacman -S gnome-shell gnome-control-center gnome-terminal fish gnome-themes-extra gnome-keyring gnome-backgrounds gnome-tweaks gnome-shell-extensions gnome-browser-connector gnome-text-editor nautilus file-roller gdm xdg-user-dirs-gtk exfatprogs f2fs-tools traceroute cronie gufw xdg-desktop-portal-gtk gnome-online-accounts gnome-system-monitor gnome-screenshot transmission-gtk gnome-calculator gnome-calendar simple-scan kdenlive mediainfo shotwell snapshot gimp xournalpp openvpn networkmanager-openvpn ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster audacity audacious celluloid mplayer bookworm obs-studio gparted ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 nodejs npm python-pip pyenv postgresql mariadb android-tools vala tk kvantum-git filezilla --noconfirm --needed
    systemctl enable gdm
elif [ $DESKTOP == "3" ]
then
    pacman -S plasma-desktop dolphin dolphin-plugins ark konsole fish okular gwenview plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm xdg-user-dirs-gtk breeze-gtk pamac-tray-icon-plasma kalk kate plasma-systemmonitor xdg-desktop-portal-gtk xdg-desktop-portal-kde exfatprogs f2fs-tools traceroute cronie ufw spectacle ktorrent merkuro skanlite kdenlive mediainfo gimp xournalpp openvpn networkmanager-openvpn ttf-ubuntu-font-family noto-fonts noto-fonts-emoji audacity celluloid mplayer bookworm obs-studio partitionmanager ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 nodejs npm python-pip pyenv postgresql mariadb android-tools vala tk filezilla --noconfirm --needed
    systemctl enable sddm 
    sed -i "s/Current=/Current=breeze/" /usr/lib/sddm/sddm.conf.d/default.conf
else
    echo "Desktop Will Not Be Installed"
fi

#GRAPGIC CARD INSTALLATION
if [ $GRAPHIC == "1" ] && [ $KERNEL == "1" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-amdgpu --noconfirm --needed
elif [ $GRAPHIC == "1" ] && [ $KERNEL == "2" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-amdgpu --noconfirm --needed
elif [ $GRAPHIC == "2" ] && [ $KERNEL == "1" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-intel --noconfirm --needed
elif [ $GRAPHIC == "2" ] && [ $KERNEL == "2" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-intel --noconfirm --needed
elif [ $GRAPHIC == "3" ] && [ $KERNEL == "1" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
elif [ $GRAPHIC == "3" ] && [ $KERNEL == "2" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
elif [ $GRAPHIC == "4" ] && [ $KERNEL == "1" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland egl-wayland xf86-video-intel nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
elif [ $GRAPHIC == "4" ] && [ $KERNEL == "2" ]
then
    pacman -Sy xorg-server xorg-xkill xorg-xwayland xorg-xlsclients xorg-xwayland xorg-xlsclients qt5-wayland glfw-wayla wayland glfw-wayland egl-wayland plasma-wayland-session xf86-video-intel nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
else
    "Graphic Card Will Not Be Installed"
fi

#OFFICE INSTALLATION
if [ $OFFICE == "1" ]
then
    pacman -S wps-office wps-office-all-dicts-win-languages libtiff5 --noconfirm --needed
elif [ $OFFICE == "2" ]
then
    pacman -S onlyoffice-bin --noconfirm --needed
elif [ $OFFICE == "3" ]
then
    pacman -S libreoffice --noconfirm --needed
else
    "Office Will Not Be Installed"
fi

#GAMING INSTALLATION
if [ $GAME == "1" ]
then
    sudo pacman -S optimus-manager optimus-manager-qt steam lutris  protonup-qt wine winetricks giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
    mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
    lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
    sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
    ncurses lib32-ncurses ocl-icd lib32-ocl-icd libxslt lib32-libxslt libva lib32-libva gtk3 \
    lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader --noconfirm --needed
    systemctl enable optimus-manager
else 
    "Gaming Apps and Drivers Will Not Be Installed"
fi

#VIRTUALBOX INSTALLATION
if [ $KERNEL == "1" ] && [ $VIRTUALBOX == "1" ]
then
    pacman -S virtualbox virtualbox-guest-utils virtualbox-guest-iso virtualbox-host-modules-arch --noconfirm --needed
elif [ $KERNEL == "2" ] && [ $VIRTUALBOX == "1" ]
then
    pacman -S virtualbox virtualbox-guest-utils virtualbox-guest-iso virtualbox-host-dkms --noconfirm --needed
else
    "Virtualbox Will Not Be Installed"
fi

REALEND


arch-chroot /mnt sh next.sh

#Rebooting The System
echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="
sleep 10
reboot
