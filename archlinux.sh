#!/usr/bin/env bash

echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

timedatectl set-ntp true
reflector --sort rate --latest 6 --protocol https --save /etc/pacman.d/mirrorlist
pacman -Sy archlinux-keyring --needed && pacman -Su

echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo ""
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ) :"
read DISK
echo "="
echo "Manual Partitioning..."
cfdisk "$DISK"
echo "="
echo "Please Enter EFI Paritition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ):"
read EFI
echo "="
echo "Please Enter Root Paritition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ):"
read ROOT
echo "="
echo "Please Choose File System:"
echo "1. Btrfs"
echo "2. Ext4"
read FILESYSTEM
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
echo "="
echo "Please Chosse The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "Please Choose Your Desktop Environment:"
echo "1. CINNAMON"
echo "2. GNOME"
echo "3. HYPRLAND"
echo "4. KDE"
echo "5. No Desktop"
read DESKTOP
echo "="
echo "Do You Want To Install Sound, Bluetooth, Printer Drivers?"
echo "y"
echo "n"
read SOUNDBLUETOOTHPRINTER
echo "="
echo "Please Choose Your Graphic Card:"
echo "1. AMD"
echo "2. INTEL"
echo "3. AMD and INTEL"
echo "4. AMD and NVIDIA"
echo "5. INTEL and NVIDIA"
echo "6. Don't install"
read GRAPHIC
echo "="
echo "Do You Want to Install Power Optimization Tools?"
echo "y"
echo "n"
read POWER
echo "="
echo "Do You Want To Install Office?"
echo "1. WPS-Office"
echo "2. OnlyOffice"
echo "3. LibreOffice"
echo "4. Don't Install"
read OFFICE
echo "="
echo "DO You Want to Install Database?"
echo "postgresql, mysql, sqlite, mssql"
echo "y"
echo "n"
read DATABASE
echo "Do You Want Add Cachyos Repo and Download the Kernel?"
echo "y"
echo "n"
read CACHYOS
echo "="
echo "Will you Gaming?"
echo "1. Yes with AMD GPU"
echo "2. Yes with INTEL GPU"
echo "3. Yes with NVIDIA GPU"
echo "4. No"
read GAMING
echo "="
echo "Do You Want to Install Plymouth?"
echo "y"
echo "n"
read PLYMOUTH
echo "="

echo "================================================================="
echo "==            Formating And Mounting The Filesystem            =="
echo "================================================================="

if [[ $FILESYSTEM == "1" ]] then
   mkfs.btrfs -f -L "ROOT" "${ROOT}"
   mount -t btrfs "${ROOT}" /mnt
   btrfs su cr /mnt/@
   btrfs su cr /mnt/@.snapshots
   umount /mnt
   mount -o defaults,noatime,ssd,compress=zstd,commit=120,subvol=@ "${ROOT}" /mnt
   mkdir -p /mnt/{boot,.snapshots}
   mount -o defaults,noatime,ssd,compress=zstd,commit=120,subvol=@.snapshots "${ROOT}" /mnt/.snapshots
   mount -t fat "${EFI}" /mnt/boot
else
   mkfs.fat -F32 -n "EFISYSTEM" "${EFI}"
   mkfs.ext4 -L "ROOT" "${ROOT}"
   mount -t ext4 "${ROOT}" /mnt
   mkdir /mnt/boot
   mount -t fat "${EFI}" /mnt/boot
   mkfs.fat -F32 -n "EFISYSTEM" "${EFI}"
fi

echo "================================================================="
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [[ $KERNEL == "1" ]] then
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers vim grub efibootmgr inotify-tools git wget curl reflector rsync networkmanager networkmanager-openvpn wpa_supplicant usb_modeswitch nss-mdns modemmanger iwd ethtool dnsutils dnsmasq dhclient wireless-regdb wireless_tools smarmontools mtools net-tools dosfstools efitools nfs-utils nilfs-utils ntfs-3g ntp openssh cronie bash-completion bash-language-server pacman-contrib pkgfile rebuild-detector mousetweaks ptop
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers vim grub efibootmgr inotify-tools git wget curl reflector rsync networkmanager networkmanager-openvpn wpa_supplicant usb_modeswitch nss-mdns modemmanger iwd ethtool dnsutils dnsmasq dhclient wireless-regdb wireless_tools smarmontools mtools net-tools dosfstools efitools nfs-utils nilfs-utils ntfs-3g ntp openssh cronie bash-completion bash-language-server pacman-contrib pkgfile rebuild-detector mousetweaks ptop
fi

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

ln -sf /usr/share/zoneinfo/"$(TIMEZONE)" /etc/localtime
hwclock --systohc

echo $HOSTNAME > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF

echo "================================================================="
echo "==             Enable Network Service, sshd, fstrim            =="
echo "================================================================="

systemctl enable NetworkManager sshd fstrim.timer

echo "================================================================="
echo "==                     Installing Grub                         =="
echo "================================================================="

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_TIMEOUT=/GRUB_TIMEOUT=0/' etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "================================================================="
echo "==                    Enable Multilib Repo                     =="
echo "================================================================="

pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "/Color/a ILoveCandy/" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 4/" /etc/pacman.conf

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf

pacman -Sy pamac-aur --noconfirm --needed

sed -i "s/^#EnableAUR/EnableAUR/" /etc/pamac.conf
pamac update all --no-confirm --needed

echo "================================================================="
echo "==                            CPU                              =="
echo "================================================================="

if [[ $CPU == "1" ]] then
    pacman -S amd-ucode
else
    pacman -S intel-ucode
if

echo "================================================================="
echo "==                    DESKTOP ENVIRONMENT                      =="
echo "================================================================="

if [[ $DESKTOP == "1" ]] then
    pacman -S cinnamon nemo nemo-fileroller kitty kitty-shell-integration kitty-terminfo starship yazi gnome-themes-extra gnome-keyring blueman lightdm lightdm-slick-greeter xdg-utils xdg-user-dirs xdg-user-dirs-gtk numlockx touchegg exfatprogs f2fs-tools traceroute gufw xdg-desktop-portal-gtk transmission-gtk gnome-calculator gnome-calendar gnome-online-accounts mailspring-bin simple-scan shotcut audacity vlc mplayer video-downloader shutter-encoder-bin snapshot flameshot gthumb gimp xournalpp pencil protonvpn-gui bookworm obs-studio gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla mintlocale lightdm-settings brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha colloid-gtk-theme-git bibata-cursor-theme kvantum plank xampp docker --noconfirm --needed
    pacman -S ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts powerline-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin pick-colour-picker --no-confirm --needed
    systemctl enable lightdm touchegg
    sed -i "s/^#greeter-session=/greeter-session=lightdm-slick-greeter/" /etc/lightdm/lightdm.conf
elif [[ $DESKTOP == "2" ]] then
    pacman -S gnome-shell gnome-control-center kitty kitty-shell-integration kitty-terminfo starship yazi gnome-bluetooth gnome-themes-extra gnome-keyring power-profiles-daemon gnome-backgrounds gnome-tweaks gnome-menus gnome-browser-connector extension-manager nautilus file-roller gdm xdg-utils xdg-user-dirs xdg-user-dirs-gtk touchegg exfatprogs f2fs-tools traceroute gufw xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-online-accounts mailspring-bin transmission-gtk gnome-calculator gnome-calendar simple-scan shotcut audacity vlc mplayer video-downloader shutter-encoder-bin snapshot flameshot eog gimp xournalpp pencil protonvpn-gui bookworm obs-studio gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git colloid-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum xampp docker extension-manager --noconfirm --needed
    pacman -S ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin pick-colour-picker --no-confirm --needed
    systemctl enable gdm touchegg
elif [[ $DESKTOP == "3" ]] then
    pacman -S hyprland hyprpaper hyprcursor hyprpicker hyprshot hyprutils hyprlock hypridle hyprwayland-scanner hyprpolkitagent hyprland-bash-completion waybar waypaper-git swww swaync grim grimblast slurp wlogout nwg-look cliphist playerctl wofi dolphin dolphin-plugins ark kitty kitty-shell-integration kitty-terminfo brightnessctl power-profiles-daemon nm-connection-editor starship yazi stow mousepad pamixer network-manager-applet viewnior sddm sddm-sugar-dark xdg-utils xdg-user-dirs xdg-user-dirs-gtk touchegg exfatprogs f2fs-tools traceroute dunst python-pywal python-requests xdg-desktop-portal-gtk xdg-desktop-portal-wrlr xdg-desktop-portal-hyprland gufw qalculate gnome-online-accounts mailspring-bin transmission-gtk simple-scan shotcut audacity vlc mplayer video-downloader shutter-encoder-bin kamoso gimp xournalpp pencil protonvpn-gui bookworm obs-studio gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib xampp docker gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum --noconfirm --needed
    pacman -S ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install hyprpanel weektodo-bin stirling-pdf-bin pick-colour-picker --no-confirm --needed
    systemctl enable sddm touchegg
    sed -i "s/Current=/Current=sugar-dark/" /usr/lib/sddm/sddm.conf.d/default.conf
elif [[ $DESKTOP == "4" ]] then
    pacman -S plasma-desktop dolphin dolphin-plugins ark kitty kitty-shell-integration kitty-terminfo starship yazi plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm xdg-utils xdg-user-dirs xdg-user-dirs-gtk touchegg breeze-gtk pamac-tray-icon-plasma qalculate xdg-desktop-portal-gtk xdg-desktop-portal-kde exfatprogs f2fs-tools traceroute gufw spectacle ktorrent merkuro skanlite mailspring-bin kdenlive audacity vlc mplayer video-downloader shutter-encoder-bin kamoso flameshot gthumb gimp xournalpp pencil protonvpn-gui bookworm obs-studio partitionmanager gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib xampp docker gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum --noconfirm --needed
    pacman -S ventoy-bin crow-translate appimagelauncher megasync-bin bleachbit 
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin pick-colour-picker --no-confirm --needed
    systemctl enable sddm touchegg
    sed -i "s/Current=/Current=breeze/" /usr/lib/sddm/sddm.conf.d/default.conf
else
    echo "Desktop Will Not be Installed"
fi

echo "================================================================="
echo "==                 Sound, Bluetooth, Printer Drivers            =="
echo "================================================================="

if [[ $SOUNDBLUETOOTHPRINTER == "y" ]] then
    pacman -S bluez bluez-utils bluez-libs bluez-hid2hci cups pipewire pipewire-audio pipewire-alsa pipewire-pulse gst-plugin-pipewire libpipewire gstreamer gst-libav gst-plugins-base gst-plugins-bad gst-plugins-ugly gst-plugins-good pavucontrol mediainfo ffmpegthumbs ffmpeg openh264 --noconfirm --needed
    systemctl enable bluetooth cups
else
    "Sound, Bluetooth, Printer Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==                   GRAPGIC CARD INSTALLATION                 =="
echo "================================================================="

if [[ $GRAPHIC == "1" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu --noconfirm --needed
elif [[ $GRAPHIC == "1" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu --noconfirm --needed
elif [[ $GRAPHIC == "2" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-intel --noconfirm --needed
elif [[ $GRAPHIC == "2" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-intel --noconfirm --needed
elif [[ $GRAPHIC == "3" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu xf86-video-intel --noconfirm --needed
elif [[ $GRAPHIC == "3" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu xf86-video-intel --noconfirm --needed
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs amdgpu nvidia nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs amdgpu nvidia-lts nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-intel nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs i915 nvidia nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xorg-xrander xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-intel nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs i915 nvidia-lts nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
else
    "Graphic Card Will Not be Installed"
fi

echo "================================================================="
echo "==                 Power Optimization Tools                    =="
echo "================================================================="

if [[ $POWER == "y" ]] then
    pamac install auto-epp
    pacman -S auto-cpufreq envycontrol
    systemctl enable --now auto-cpufreq
else
    "Power Optimization Tools Will be Not Installed"
if

echo "================================================================="
echo "==                      OFFICE INSTALLATION                    =="
echo "================================================================="

if [[ $OFFICE == "1" ]] then
    pacman -S wps-office wps-office-all-dicts-win-languages libtiff5 --noconfirm --needed
elif [[ $OFFICE == "2" ]] then
    pacman -S onlyoffice-bin --noconfirm --needed
elif [[ $OFFICE == "3" ]] then
    pacman -S libreoffice --noconfirm --needed
else
    "Office Will Not be Installed"
fi

echo "================================================================="
echo "==                           DATABASE                          =="
echo "================================================================="

if [[ $DATABASE == "1" ]] then
    pacman -S postgresql sqlite --noconfirm --needed
    pamac install mysql mssql-server dbgate-bin --no-confirm --needed
else
    "Database Will Mot be Installed"
fi

echo "================================================================="
echo "==                           Cachyos                           =="
echo "================================================================="

if [[ $CACHYOS == "1" ]] then
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key F3B607488DB35A47 

    pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-18-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-18-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-6-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.0.0.r6.gc685ae6-2-x86_64.pkg.tar.zst'

    echo -e "\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
    echo -e "\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
    echo -e "\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf

     pacman -Sy pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
else
    "Cachyos Repo and Kernel Will Mot be Installed"
fi

echo "================================================================="
echo "==                      GAMING INSTALLATION                    =="
echo "================================================================="

if [[ $GAMING == "1" ]] then
    pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation proton-cachyos wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
elif [[ $GAMING == "2" ]] then
    pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation proton-cachyos wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
elif [[ $GAMING == "3" ]] then
    pacman -S linux-cachyos linux-cachyos-headers linux-cachyos-nvidia-open nvidia-utils nvidia-settings lib32-nvidia-utils nvidia-prime opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation proton-cachyos wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
else 
    "Gaming Apps and Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==           Plymouth Installation and Congratulations         =="
echo "================================================================="

if [[ $PLYMOUTH == "y" ]] then
    pacman -S plymouth --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash udev.log_priority=3"/' /etc/default/grub
    sed -i 's/HOOKS=/HOOKS="base systemd plymouth autodetect keyboard sd-vconsole modconf block filesystems fsck"/' /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
else
    "Plymouth Will Mot be Installed"
fi

echo "================================================================="
echo "==            Timeshift and Snapshot Configuration             =="               
echo "================================================================="

if [[ $FILESYSTEM == "1" ]] then
   pacman -S grub-btrfs btrfs-progs timeshift timeshift-autosnap
   systemctl enable grub-btrfsd
   sed -i 's/^#ExecStart=/ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto/' systemctl edit --full grub-btrfsd
else
    pacman -S timeshift
fi


REALEND

arch-chroot /mnt sh next.sh

# Rebooting The System
echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="

sleep 10
reboot
