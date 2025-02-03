#!/usr/bin/env bash
echo ""
echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

timedatectl set-ntp true
reflector --sort rate --latest 6 --protocol https --save /etc/pacman.d/mirrorlist

echo ""
echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo ""
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ) :"
read DISK
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
echo "="
echo "Please Chosse The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "Please Choose Your Desktop Environment:"
echo "1. CINNAMON"
echo "2. CUTEFISH"
echo "3. DEEPIN"
echo "4. GNOME"
echo "5. HYPRLAND"
echo "6. KDE"
echo "7. No Desktop"
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
echo "="
read OFFICE
echo "="
echo "DO You Want to Install Database?"
echo "postgresql, mysql, sqlite, mssql"
echo "y"
echo "n"
read DATABASE
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
echo "==                      Format And Mount                       =="
echo "================================================================="

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
mkfs.btrfs -f -L "ROOT" "${ROOT}"

mount -t btrfs "${ROOT}" /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@.snapshots
umount /mnt
mount -o defaults,noatime,ssd,compress=zstd,commit=120,subvol=@ "${ROOT}" /mnt
mkdir -p /mnt/{boot,.snapshots}
mount -o defaults,noatime,ssd,compress=zstd,commit=120,subvol=@.snapshots "${ROOT}" /mnt/.snapshots
mount -t vfat "${EFI}" /mnt/boot

echo "================================================================="
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [[ $KERNEL == "1" ]] then
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers gvim micro grub efibootmgr grub-btrfs btrfs-progs inotify-tools git wget curl reflector rsync networkmanager wireless_tools iwd smarmontools mtools net-tools dosfstools openssh cronie bash-completion bash-language-server xf86-input-libinput libinput touchegg
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers gvim micro grub efibootmgr grub-btrfs btrfs-progs inotify-tools git wget curl reflector rsync networkmanager wireless_tools iwd smarmontools mtools net-tools dosfstools openssh cronie bash-completion bash-language-server xf86-input-libinput libinput touchegg
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
echo "==                  Enable Network Service                     =="
echo "================================================================="

systemctl enable NetworkManager sshd touchegg fstrim.timer grub-btrfsd
sed -i 's/^#ExecStart=/ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto/' systemctl edit --full grub-btrfsd

echo "================================================================="
echo "==                     Installing Grub                         =="
echo "================================================================="

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux
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
sed -i "/Color/a ILoveCandy" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 4/" /etc/pacman.conf

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
echo -e "\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
echo -e "\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
echo -e "\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf

pacman -Sy pamac-aur --noconfirm --needed

sed -i "s/^#EnableAUR/EnableAUR/" /etc/pamac.conf
pamac update all --no-confirm --needed

echo "================================================================="
echo "=                             CPU                               ="
echo "================================================================="

if [[ $CPU == "1" ]] then
    pacman -S amd-ucode
else
    pacman -S intel-ucode
if

echo "================================================================="
echo "=                     DESKTOP ENVIRONMENT                       ="
echo "================================================================="

if [[ $DESKTOP == "1" ]] then
    pacman -S cinnamon nemo nemo-fileroller kitty kitty-shell-integration kitty-terminfo starship ptop yazi gnome-themes-extra gnome-keyring blueman lightdm lightdm-slick-greeter xdg-utils xdg-user-dirs xdg-user-dirs-gtk numlockx exfatprogs f2fs-tools traceroute gufw xdg-desktop-portal-gtk transmission-gtk gnome-calculator gnome-calendar gnome-online-accounts mailspring-bin simple-scan shotcut audacity vlc mplayer video-downloader shutter-encoder-bin cheese flameshot gthumb gimp xournalpp openvpn networkmanager-openvpn pencil protonvpn-gui bookworm obs-studio gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla mintlocale lightdm-settings brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha colloid-gtk-theme-git bibata-cursor-theme kvantum plank xampp docker --noconfirm --needed
    pacman -S timeshift timeshift-autosnap ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts powerline-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin thorium-browser-bin pick-colour-picker --no-confirm --needed
    pacman -S pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
    systemctl enable lightdm
    sed -i "s/^#greeter-session=/greeter-session=lightdm-slick-greeter/" /etc/lightdm/lightdm.conf
    elif [[ $DESKTOP == "2" ]] then
    sed -i "s/^#IgnorePkg=/IgnorePkg=cutefish-terminal/" /etc/pacman.conf
    pacman -Sy cutefish fishui cutefish-qt-plugins libcutefish ark polkit-kde-agent kwin kitty kitty-shell-integration kitty-terminfo starship ptop yazi sddm xdg-utils xdg-user-dirs xdg-user-dirs-gtk exfatprogs f2fs-tools traceroute gufw xdg-desktop-portal-gtk gnome-online-accounts mailspring-bin transmission-gtk simple-scan kdenlive audacity vlc mplayer video-downloader shutter-encoder-bin cheese flameshot gthumb gimp xournalpp openvpn networkmanager-openvpn pencil protonvpn-gui bookworm gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib gtk-engine-murrine orchis-theme candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum xampp docker --noconfirm --needed
    pacman -S timeshift timeshift-autosnap ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin thorium-browser-bin pick-colour-picker --no-confirm --needed
    pacman -S pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
    systemctl enable sddm
    sed -i "s/Current=/Current=breeze/" /usr/lib/sddm/sddm.conf.d/default.conf
elif [[ $DESKTOP == "3" ]] then
    pacman -S deepin deepin-kwin kitty kitty-shell-integration kitty-terminfo starship ptop yazi deepin-camera deepin-compressor deepin-printer deepin-voice-note deepin-screen-recorder deepin-music deepin-video deepin-calculator polkit-kde-agent lightdm lightdm-deepin-greeter xdg-utils xdg-user-dirs xdg-user-dirs-gtk exfatprogs f2fs-tools traceroute gufw xdg-desktop-portal-gtk gnome-online-accounts mailspring-bin transmission-gtk simple-scan shotcut audacity mplayer video-downloader shutter-encoder-bin flameshot gthumb gimp xournalpp openvpn networkmanager-openvpn pencil protonvpn-gui bookworm gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla lightdm-settings brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum xampp docker --noconfirm --needed
    pacman -S timeshift timeshift-autosnap ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin thorium-browser-bin pick-colour-picker --no-confirm --needed
    pacman -S pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
    systemctl enable lightdm
    sed -i "s/^#greeter-session=/greeter-session=lightdm-deepin-greeter/" /etc/lightdm/lightdm.conf
elif [[ $DESKTOP == "4" ]] then
    pacman -S gnome-shell gnome-control-center kitty kitty-shell-integration kitty-terminfo starship ptop yazi gnome-bluetooth gnome-themes-extra gnome-keyring power-profiles-daemon gnome-backgrounds gnome-tweaks gnome-menus gnome-browser-connector extension-manager nautilus file-roller gdm xdg-utils xdg-user-dirs xdg-user-dirs-gtk exfatprogs f2fs-tools traceroute gufw xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-online-accounts mailspring-bin transmission-gtk gnome-calculator gnome-calendar simple-scan shotcut audacity vlc mplayer video-downloader shutter-encoder-bin cheese flameshot gthumb gimp xournalpp openvpn networkmanager-openvpn pencil protonvpn-gui bookworm obs-studio gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git colloid-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum xampp docker extension-manager --noconfirm --needed
    pacman -S timeshift timeshift-autosnap ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install mailspring-bin weektodo-bin stirling-pdf-bin thorium-browser-bin pick-colour-picker --no-confirm --needed
    pacman -S pacman cachyos-kernel-manager cachyos-settings --noconfirm --needed
    systemctl enable gdm
elif [[ $DESKTOP == "5" ]] then
    pacman -S hyprland hyprpaper hyprcursor hyprpicker hyprshot hyprutils hyprlock hypridle hyprwayland-scanner hyprpolkitagent hyprland-bash-completion waybar waypaper-git swww swaync grim grimblast slurp wlogout nwg-look cliphist playerctl wofi dolphin dolphin-plugins ark kitty kitty-shell-integration kitty-terminfo brightnessctl power-profiles-daemon nm-connection-editor starship ptop yazi stow mousepad pamixer network-manager-applet viewnior sddm sddm-sugar-dark xdg-utils xdg-user-dirs xdg-user-dirs-gtk exfatprogs f2fs-tools traceroute dunst python-pywal python-requests xdg-desktop-portal-gtk xdg-desktop-portal-wrlr xdg-desktop-portal-hyprland gufw qalculate gnome-online-accounts mailspring-bin transmission-gtk simple-scan shotcut audacity vlc mplayer video-downloader shutter-encoder-bin cheese gimp xournalpp openvpn networkmanager-openvpn pencil protonvpn-gui bookworm obs-studio gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib xampp docker gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum --noconfirm --needed
    pacman -S timeshift timeshift-autosnap ventoy-bin crow-translate appimagelauncher megasync-bin fastfetch bleachbit --noconfirm --needed
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install hyprpanel weektodo-bin stirling-pdf-bin thorium-browser-bin pick-colour-picker --no-confirm --needed
    pacman -S pacman cachyos-kernel-managertchy op-ed El-Naggar oconfirm fastfetch --needed
    systemctl enable sddm
    sed -i "s/Current=/Current=sugar-dark/" /usr/lib/sddm/sddm.conf.d/default.conf
elif [[ $DESKTOP == "6" ]] then
    pacman -S plasma-desktop dolphin dolphin-plugins ark kitty kitty-shell-integration kitty-terminfo starship ptop yazi plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm xdg-utils xdg-user-dirs xdg-user-dirs-gtk breeze-gtk pamac-tray-icon-plasma qalculate xdg-desktop-portal-gtk xdg-desktop-portal-kde exfatprogs f2fs-tools traceroute gufw spectacle ktorrent merkuro skanlite mailspring-bin kdenlive audacity vlc mplayer video-downloader shutter-encoder-bin flameshot gthumb gimp xournalpp openvpn networkmanager-openvpn pencil protonvpn-gui bookworm obs-studio partitionmanager gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs php nodejs npm yarn python-pip pyenv android-tools vala tk filezilla brave-bin downgrade debtap dpkg vscodium postman-bin xclip python-xlib xampp docker gtk-engine-murrine orchis-theme cutefish-icons candy-icons-git papirus-folders-nordic papirus-folders dracula-gtk-theme-git catppuccin-gtk-theme-mocha bibata-cursor-theme kvantum --noconfirm --needed
    pacman -S timeshift timeshift-autosnap ventoy-bin crow-translate appimagelauncher megasync-bin bleachbit 
    pacman -S zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting zsh-history-substring-search --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome --noconfirm --needed
    pamac install weektodo-bin stirling-pdf-bin thorium-browser-bin pick-colour-picker --no-confirm --needed
    pacman -S pacman cachyos-kernel-managertchy op-ed El-Naggar oconfirm fastfetch --needed
    systemctl enable sddm 
    sed -i "s/Current=/Current=breeze/" /usr/lib/sddm/sddm.conf.d/default.conf
else
    echo "Desktop Will Not be Installed"
fi

echo "================================================================="
echo "=                  Sound, Bluetooth, Printer Drivers            ="
echo "================================================================="

if [[ $SOUNDBLUETOOTHPRINTER == "y" ]] then
    pacman -S bluez bluez-utils cups pipewire pipewire-audio pipewire-alsa pipewire-pulse gst-plugin-pipewire libpipewire gstreamer gst-libav gst-plugins-base gst-plugins-bad gst-plugins-ugly gst-plugins-good pavucontrol mediainfo ffmpegthumbs ffmpeg openh264 --noconfirm --needed
    systemctl enable bluetooth cups
else
    "Sound, Bluetooth, Printer Drivers Will Not be Installed"
fi

echo "================================================================="
echo "=                    GRAPGIC CARD INSTALLATION                  ="
echo "================================================================="

if [[ $GRAPHIC == "1" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu mesa-utils --noconfirm --needed
elif [[ $GRAPHIC == "1" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu mesa-utils --noconfirm --needed
elif [[ $GRAPHIC == "2" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-intel mesa-utils --noconfirm --needed
elif [[ $GRAPHIC == "2" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-intel mesa-utils --noconfirm --needed
elif [[ $GRAPHIC == "3" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu xf86-video-intel mesa-utils  --noconfirm --needed
elif [[ $GRAPHIC == "3" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland xf86-video-amdgpu xf86-video-intel mesa-utils --noconfirm --needed
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs amdgpu nvidia nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-amdgpu nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs amdgpu nvidia-lts nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-intel nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs i915 nvidia nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "2" ]] then
    pacman -S xorg-server xorg-xkill xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols kwayland qt5-wayland qt6-wayland glfw-wayland egl-wayland xf86-video-intel nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    sed -i 's/GRUB_CMDLINE_LINUX=/GRUB_CMDLINE_LINUX="rootfstype=btrfs nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
    sed -i "/MODULES=/MODULES=(btrfs i915 nvidia-lts nvidia_modset nvidia_drm nvidia_uvm)" /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
else
    "Graphic Card Will Not be Installed"
fi

echo "================================================================="
echo "=                  Power Optimization Tools                     ="
echo "================================================================="

if [[ $POWER == "y" ]] then
    pamac install auto-epp
    pacman -S auto-cpufreq envycontrol
    systemctl enable --now auto-cpufreq
else
    "Power Optimization Tools Will be Not Installed"
if

echo "================================================================="
echo "=                       OFFICE INSTALLATION                     ="
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
echo "=                            DATABASE                          ="
echo "================================================================="

if [[ $DATABASE == "1" ]] then
    pacman -S postgresql sqlite --noconfirm --needed
    pamac install mysql mssql-server dbgate-bin --no-confirm --needed
else
    "Database Will Mot be Installed"
fi

echo "================================================================="
echo "=                       GAMING INSTALLATION                     ="
echo "================================================================="

if [[ $GAMING == "1" ]] then
    sudo pacman -S linux-cachyos linux-cachyos-headers mesa-utils --noconfirm --needed
    sudo pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal proton-cachyos ttf-liberation wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    sudo pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
elif [[ $GAMING == "2" ]] then
    sudo pacman -S linux-cachyos linux-cachyos-headers mesa-utils --noconfirm --needed
    sudo pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal proton-cachyos ttf-liberation wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    sudo pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
elif [[ $GAMING == "3" ]] then
    sudo pacman -S linux-cachyos linux-cachyos-headers linux-cachyos-nvidia-open nvidia-utils nvidia-settings lib32-nvidia-utils nvidia-prime opencl-nvidia libxnvctrl libxcrypt-compat mesa-utils --noconfirm --needed
    sudo pacman -S gifli glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal proton-cachyos ttf-liberation wine-cachyos wine-gecko wine-mono winetricks vulkan-tools --noconfirm --needed
    sudo pacman -S gamescope heroic-games-launcher lib32-mangohud lutris mangohud steam steam-native-runtime wqy-zenhei--noconfirm --needed
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

REALEND

arch-chroot /mnt sh next.sh

# Rebooting The System
echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="

sleep 10
reboot
