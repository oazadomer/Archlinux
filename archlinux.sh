#!/usr/bin/env bash
echo ""
echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

timedatectl set-ntp true
reflector --sort rate --latest 20 --protocol https --save /etc/pacman.d/mirrorlist

echo ""
echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo ""
# Display available disks for the user to choose
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ) :"
read DISK
# Manual partitioning
echo "Manual Partitioning..."
cfdisk "$DISK"
echo "="
echo "Please Enter EFI Paritition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ):"
read EFI
echo "="
echo "Please Enter Root Paritition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ):"
read ROOT
echo "="
echo "Please Enter Your hostname:"
read HOSTNAME
echo "="
echo "Please Enter Your hostname password:"
read HOSTNAMEPASSWORD
echo "="
echo "Please Enter Your username:"
read USERNAME
echo "="
echo "Please Enter Your username password:"
read USERNAMEPASSWORD
echo "="
echo "Enter Your Locale ( Example: en_US.UTF-8 ):"
read LOCALE
echo "="
echo "Enter Your Keyboard Layout ( Example: us ):"
read KEYBOARD_LAYOUT
echo "="
echo "Enter your Time Zone: ( Example: Europe/Istanbul )"
read TIMEZONE
echo "="
echo "Please choose your CPU"
echo "1. AMD"
echo "2. Intel"
read CPU
echo"="
echo "Please Chosse The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "Please Choose Your Desktop Environment:"
echo "1. CINNAMON"
echo "2. GNOME"
echo "3. KDE"
echo "4. No Desktop"
read DESKTOP
echo "="
echo "Do You Want To Install Sound, Bluetooth, Printer Drivers:"
echo "1. Yes"
echo "2. No"
read SOUNDBLUETOOTHPRINTER
echo "="
echo "Please Choose Your Graphic Card:"
echo "1. AMD"
echo "2. INTEL"
echo "3. AMD and NVIDIA"
echo "4. INTEL and NVIDIA"
echo "5. Don't install"
read GRAPHIC
echo "="
echo "Do You Want To Install Office:"
echo "1. WPS-Office"
echo "2. OnlyOffice"
echo "3. LibreOffice"
echo "4. Don't Install"
read OFFICE
echo "="
echo "Will you Gaming:"
echo "1. Yes"
echo "2. No"
read GAMING
echo "="

echo "================================================================="
echo "==                      Format And Mount                       =="
echo "================================================================="

mkfs.fat -F32 -n "EFISYSTEM" "${EFI}"
mkfs.btrfs -L "ROOT" "${ROOT}"

mount -t btrfs "${ROOT}" /mnt
btrfs su cr /mnt/@
umount /mnt
mount -o noatime,ssd,compress=zstd,space_cache=v2,discord=async,subvol=@ "${ROOT}" /mnt
mkdir -p /mnt/boot/efi
mount -t fat "${EFI}" /mnt/boot/efi

echo "================================================================="
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [ $KERNEL == "1" ]
then
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers micro grub efibootmgr btrfs-progs git wget reflector rsync networkmanager wireless_tools mtools net-tools dosfstools openssh cron
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers micro grub efibootmgr btrfs-progs git wget reflector rsync networkmanager wireless_tools mtools net-tools dosfstools openssh cron
fi

#fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
echo "$HOSTNAME:$HOSTNAMEPASSWORD" | chpasswd
useradd -mG wheel "$USERNAME"
echo "$USERNAME:$USERNAMEPASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "================================================================="
echo "==                 Setup Language and Set Locale               =="
echo "================================================================="

sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
echo "LANG=$LOCALE" >> /etc/locale.conf
echo "KEYMAP=$KEYBOARD_LAYOUT" >> /etc/vconsole.conf
locale-gen

ln -sf /usr/share/zoneinfo/"$(TIMEZONE)" /etc/localtime
hwclock --systohc

echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	"$HOSTNAME".localdomain	"$HOSTNAME"
EOF

echo "================================================================="
echo "==                  Enable Network Service                     =="
echo "================================================================="
systemctl enable NetworkManager sshd fstrim.timer

echo "================================================================="
echo "==                     Installing Grub                         =="
echo "================================================================="

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Archlinux
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
echo -e "\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
echo -e "\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
echo -e "\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf

pacman -Syyu pamac-aur --noconfirm --needed

sed -i "s/^#EnableAUR/EnableAUR/" /etc/pamac.conf
pamac update all --no-confirm --needed
pamac install oh-my-posh stacer-bin --no-confirm mysql --needed

echo "================================================================="
echo "=                             CPU                               ="
echo "================================================================="
if [ $CPU == "1" ]
then
    pacman -S amd-ucode
else
    pacman -S intel-ucode
if

echo "================================================================="
echo "=                     DESKTOP ENVIRONMENT                       ="
echo "================================================================="
if [ $DESKTOP == "1" ]
then
    pacman -S cinnamon nemo nemo-fileroller gedit ptyxis fish gnome-themes-extra gnome-keyring system-config-printer lightdm lightdm-slick-greeter xdg-user-dirs xdg-user-dirs-gtk blueman numlockx exfatprogs f2fs-tools traceroute cronie gufw xdg-desktop-portal-gtk gnome-system-monitor gnome-screenshot transmission-gtk qalculate gnome-calendar simple-scan shotcut audacity vlc mplayer shutter-encoder-bin mediainfo eog cheese gimp xournalpp redshift openvpn networkmanager-openvpn ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster pencil protonvpn-gui bookworm obs-studio gparted ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 php nodejs npm yarn python-pip pyenv postgresql android-tools vala tk filezilla kvantum mintlocale lightdm-settings brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib colloid-gtk-theme-git xampp docker --noconfirm --needed
    pacman -S timeshift timeshift-autosnap plymouth ventoy-bin crow-translate appimagelauncher megasync-bin ttf-ms-fonts bibata-cursor-theme fastfetch --noconfirm --needed
    pacman -S pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
    systemctl enable lightdm
    sed -i "s/^#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/" /etc/lightdm/lightdm.conf
elif [ $DESKTOP == "2" ]
then
    pacman -S gnome-shell gnome-control-center ptyxis fish gnome-bluetooth gnome-themes-extra gnome-keyring gnome-backgrounds gnome-tweaks gnome-menus gnome-browser-connector gedit nautilus file-roller gdm xdg-user-dirs xdg-user-dirs-gtk exfatprogs f2fs-tools traceroute cronie gufw xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-online-accounts gnome-system-monitor gnome-screenshot transmission-gtk gnome-calculator gnome-calendar gnome-clocks simple-scan shotcut audacity vlc mplayer shutter-encoder-bin mediainfo eog cheese gimp xournalpp openvpn networkmanager-openvpn ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster pencil protonvpn-gui bookworm obs-studio gparted ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 php nodejs npm yarn python-pip pyenv postgresql android-tools vala tk filezilla kvantum brave-bin downgrade debtap dpkg vscodium postman-bin colloid-gtk-theme-git xampp docker extension-manager --noconfirm --needed
    pacman -S timeshift timeshift-autosnap plymouth ventoy-bin crow-translate appimagelauncher megasync-bin ttf-ms-fonts bibata-cursor-theme fastfetch --noconfirm --needed
    pacman -S pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
    systemctl enable gdm
elif [ $DESKTOP == "3" ]
then
    pacman -S plasma-desktop dolphin dolphin-plugins ark konsole fish okular gthumb plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm xdg-user-dirs xdg-user-dirs-gtk breeze-gtk pamac-tray-icon-plasma qalculate kate plasma-systemmonitor xdg-desktop-portal-gtk xdg-desktop-portal-kde exfatprogs f2fs-tools traceroute cronie ufw spectacle ktorrent merkuro skanlite kdenlive audacity vlc mplayer shutter-encoder-bin mediainfo gimp xournalpp openvpn networkmanager-openvpn ttf-ubuntu-font-family noto-fonts noto-fonts-emoji pencil protonvpn-gui bookworm obs-studio partitionmanager ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 php nodejs npm yarn python-pip pyenv postgresql android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xampp docker --noconfirm --needed
    pacman -S timeshift timeshift-autosnap plymouth ventoy-bin crow-translate appimagelauncher megasync-bin ttf-ms-fonts bibata-cursor-theme --noconfirm --needed
    pacman -S pacman cachyos-kernel-managertchy op-ed El-Naggar oconfirm fastfetch --needed
    systemctl enable sddm 
    sed -i "s/Current=/Current=breeze/" /usr/lib/sddm/sddm.conf.d/default.conf
else
    echo "Desktop Will Not Be Installed"
fi

echo "================================================================="
echo "=                  Sound, Bluetooth, Printer Drivers            ="
echo "================================================================="
if [ $SOUNDBLUETOOTHPRINTER == "1" ]
then
    pacman -S bluez bluez-utils cups touchegg pipewire pipewire-audio pipewire-alsa pipewire-pulse libpipewire pavucontrol xf86-input-libinput libinput bash-completion --noconfirm --needed
    systemctl enable bluetooth cups touchegg
else
    "Bluetooth & Printer Drivers Will Not Be Installed"
fi

echo "================================================================="
echo "=                    GRAPGIC CARD INSTALLATION                  ="
echo "================================================================="
if [ $GRAPHIC == "1" ] && [ $KERNEL == "1" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-amdgpu mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "1" ] && [ $KERNEL == "2" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-amdgpu mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "2" ] && [ $KERNEL == "1" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-intel mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "2" ] && [ $KERNEL == "2" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland xf86-video-intel mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "3" ] && [ $KERNEL == "1" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "3" ] && [ $KERNEL == "2" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "4" ] && [ $KERNEL == "1" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland glfw-wayland egl-wayland xf86-video-intel nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
elif [ $GRAPHIC == "4" ] && [ $KERNEL == "2" ]
then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients xorg-xwayland xorg-xlsclients qt5-wayland glfw-wayla wayland glfw-wayland egl-wayland plasma-wayland-session xf86-video-intel nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
else
    "Graphic Card Will Not Be Installed"
fi

echo "================================================================="
echo "=                       OFFICE INSTALLATION                     ="
echo "================================================================="
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

echo "================================================================="
echo "=                       GAMING INSTALLATION                     ="
echo "================================================================="
if [ $GAMING == "1" ]
then
    sudo pacman -S linux-cachyos linux-cachyos-headers linux-cachyos-nvidia-open nvidia-utils nvidia-settings lib32-nvidia-utils nvidia-prime opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    sudo pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal proton-cachyos ttf-liberation wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    sudo pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
else 
    "Gaming Apps and Drivers Will Not Be Installed"
fi

REALEND


arch-chroot /mnt sh next.sh

#Rebooting The System
echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="
sleep 10
reboot
