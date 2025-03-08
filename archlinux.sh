#!/usr/bin/env bash

echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

pacman-key --init; pacman-key --populate archlinux; pacman -Sy archlinux-keyring --noconfirm --needed
timedatectl set-ntp true
reflector --latest 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy

echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo ""
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "# Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ) :"
read DISK
echo "="
echo "Manual Partitioning..."
cfdisk "$DISK"
echo "="
echo "# Please Enter EFI Paritition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ):"
read EFI
echo "="
echo "# Please Enter Root Paritition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ):"
read ROOT
echo "="
echo "# Please Choose File System:"
echo "1. Btrfs"
echo "2. Ext4"
read FILESYSTEM
echo "="
echo "# Please Enter Your hostname:"
read HOSTNAME
echo "="
echo "# Please Enter Your hostname password:"
read HOSTNAMEPASSWORD
echo "="
echo "# Please Enter Your username:"
read USERNAME
echo "="
echo "# Please Enter Your username password:"
read USERNAMEPASSWORD
echo "="
echo "# Enter Your Locale ( Example: en_US.UTF-8 ):"
read LOCALE
echo "="
echo "# Enter Your Keyboard Layout ( Example: us ):"
read KEYBOARD_LAYOUT
echo "="
echo "# Enter your Time Zone: ( Example: Europe/Istanbul )"
read TIMEZONE
echo "="
echo "# Please choose your CPU"
echo "1. AMD"
echo "2. Intel"
read CPU
echo "="
echo "# Please Chosse The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "# Please Choose Your Desktop Environment:"
echo "1. CINNAMON"
echo "2. GNOME"
echo "3. KDE"
echo "n. No Desktop"
read DESKTOP
echo "="
echo "# Do You Want To Install Sound, Bluetooth, Printer Drivers?"
echo "y"
echo "n"
read SOUNDBLUETOOTHPRINTER
echo "="
echo "# Please Choose Your Graphic Card:"
echo "1. AMD"
echo "2. INTEL"
echo "3. AMD and INTEL"
echo "4. AMD and NVIDIA"
echo "5. INTEL and NVIDIA"
echo "n. Don't install"
read GRAPHIC
echo "="
echo "# Do You Want to Install Power Optimization Tools?"
echo "y"
echo "n"
read POWER
echo "="
echo "# Do You Want To Install Office?"
echo "1. WPS-Office"
echo "2. OnlyOffice"
echo "3. LibreOffice"
echo "n. Don't Install"
read OFFICE
echo "="
echo "# DO You Want to Install Database?"
echo "postgresql, mysql, sqlite"
echo "y"
echo "n"
read DATABASE
echo "="
echo "# Will you Gaming?"
echo "y"
echo "n"
read GAMING
echo "="
echo "# Do You Want to Install VirtualBox?"
echo "1. Yes With Linux Kernel"
echo "2. Yes With Linux LTS"
echo "n"
read VBOX
echo "="
echo "# Do You Want to Install Plymouth?"
echo "y"
echo "n"
read PLYMOUTH
echo "="

echo "================================================================="
echo "==            Formating And Mounting The Filesystem            =="
echo "================================================================="

if [[ $FILESYSTEM == "1" ]] then
   mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
   mkfs.btrfs -f -L "ROOT" "${ROOT}"
   mount -t btrfs "${ROOT}" /mnt
   btrfs su cr /mnt/@
   btrfs su cr /mnt/@.snapshots
   umount /mnt
   mount -o defaults,noatime,ssd,compress=zstd,commit=120,subvol=@ "${ROOT}" /mnt
   mkdir -p /mnt/{boot,.snapshots}
   mount -o defaults,noatime,ssd,compress=zstd,commit=120,subvol=@.snapshots "${ROOT}" /mnt/.snapshots
   mount -t vfat "${EFI}" /mnt/boot/
else
   mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
   mkfs.ext4 -L "ROOT" "${ROOT}"
   mount -t ext4 "${ROOT}" /mnt
   mkdir /mnt/boot
   mount -t vfat "${EFI}" /mnt/boot/
fi

echo "================================================================="
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [[ $KERNEL == "1" ]] then
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers zsh gvim grub efibootmgr inotify-tools git python rust gcc make cmake less wget curl libaio reflector rsync networkmanager usb_modeswitch wireless_tools smartmontools mtools net-tools dosfstools efitools nfs-utils nilfs-utils exfatprogs ntfs-3g ntp openssh cronie bash-completion pacman-contrib pkgfile rebuild-detector mousetweaks usbutils zram-generator                                          
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers zsh gvim grub efibootmgr inotify-tools git python rust gcc make cmake less wget curl libaio reflector rsync networkmanager usb_modeswitch wireless_tools smartmontools mtools net-tools dosfstools efitools nfs-utils nilfs-utils exfatprogs ntfs-3g ntp openssh cronie bash-completion pacman-contrib pkgfile rebuild-detector mousetweaks usbutils zram-generator                                                  
fi

genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh

echo "$HOSTNAME:$HOSTNAMEPASSWORD" | chpasswd
useradd -mG wheel $USERNAME
echo "$USERNAME:$USERNAMEPASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# zram
echo -e "\[zram0]\nzram-size=ram\n" >> /usr/lib/systemd/zram-generator.conf
echo -e "\compression-algorithm=zstd\nswap-priority=60\n" >> /usr/lib/systemd/zram-generator.conf

systemctl daemon-reload
systemctl start /dev/zram0

echo "================================================================="
echo "==                 Setup Language and Set Locale               =="
echo "================================================================="

sed -i 's/^#$LOCALE/$LOCALE/' /etc/locale.gen
echo "LANG=$LOCALE" >> /etc/locale.conf
echo "KEYMAP=$KEYBOARD_LAYOUT" >> /etc/vconsole.conf
locale-gen

ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
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

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux

sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet zswap.enabled=0"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

echo "================================================================="
echo "==                    Enable Multilib Repo                     =="
echo "================================================================="
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i '/Color/a ILoveCandy' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/ParallelDownloads = 5/ParallelDownloads = 2/' /etc/pacman.conf

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf

pacman -Sy; pacman -S pamac --noconfirm --needed

sed -i 's/^#EnableAUR/EnableAUR/' /etc/pamac.conf
sed -i 's/^#EnableFlatpak/EnableFlatpak/' /etc/pamac.conf      
sed -i 's/MaxParallelDownloads = 4/MaxParallelDownloads = 2/' /etc/pamac.conf

pacman -Syu --noconfirm
pamac update --aur --force-refresh
pamac update all --no-confirm

echo "================================================================="
echo "==                            CPU                              =="
echo "================================================================="

if [[ $CPU == "1" ]] then
    pacman -S amd-ucode --noconfirm --needed

else
    pacman -S intel-ucode --noconfirm --needed
fi

echo "================================================================="
echo "==                    DESKTOP ENVIRONMENT                      =="
echo "================================================================="

if [[ $DESKTOP == "1" ]] then
    pacman -S cinnamon nemo nemo-fileroller kitty kitty-shell-integration kitty-terminfo btop starship yazi gnome-themes-extra gnome-keyring geary blueman lightdm lightdm-slick-greeter xdg-utils xdg-user-dirs-gtk numlockx touchegg f2fs-tools traceroute gufw xdg-desktop-portal-gtk transmission-gtk gnome-calculator gnome-calendar gnome-online-accounts simple-scan shotcut audacity decibels vlc mplayer video-downloader shutter-encoder-bin snapshot flameshot gthumb gimp xournalpp proton-vpn-gtk-app gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs-lts-iron npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla mintlocale lightdm-settings brave-bin zen-browser-bin downgrade dpkg vscodium postman-bin xclip python-xlib xampp docker flatpak bibata-cursor-theme --noconfirm --needed
    pacman -S yay xdg-terminal-exec-git ollama proton-vpn-gtk-app libappindicator-gtk3 gnome-shell-extension-appindicator papirus-folders ventoy-bin appimagelauncher telegram-desktop zsh-theme-powerlevel10k-git --noconfirm --needed
    pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts powerline-fonts ttf-font-awesome awesome-terminal-fonts --noconfirm --needed
# pamac install megasync-bin crow-translate papirus-folders-nordic --no-confirm 
    
    systemctl enable lightdm touchegg
    export TERM="kitty"
    export TERMINAL="kitty"
    sed -i 's/^#greeter-session=/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
elif [[ $DESKTOP == "2" ]] then
      pacman -S gnome-shell gnome-control-center kitty kitty-shell-integration kitty-terminfo btop starship yazi gnome-bluetooth gnome-themes-extra gnome-keyring geary power-profiles-daemon gnome-backgrounds gnome-tweaks gnome-menus gnome-screenshot gnome-online-accounts extension-manager nautilus file-roller gdm xdg-utils xdg-user-dirs-gtk touchegg f2fs-tools traceroute gufw xdg-desktop-portal-gtk xdg-desktop-portal-gnome transmission-gtk gnome-calculator gnome-calendar simple-scan shotcut audacity decibels vlc mplayer video-downloader shutter-encoder-bin snapshot gthumb gimp xournalpp proton-vpn-gtk-app gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs-lts-iron npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin zen-browser-bin downgrade dpkg vscodium postman-bin xclip python-xlib xampp docker flatpak bibata-cursor-theme --noconfirm --needed
      pacman -S yay xdg-terminal-exec-git ollama proton-vpn-gtk-app libappindicator-gtk3 gnome-shell-extension-appindicator papirus-folders ventoy-bin appimagelauncher telegram-desktop zsh-theme-powerlevel10k-git --noconfirm --needed
      pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome awesome-terminal-fonts powerline-fonts --noconfirm --needed
# pamac install megasync-bin crow-translate papirus-folders-nordic --no-confirm
 
    systemctl enable gdm touchegg
    export TERM="kitty"
    export TERMINAL="kitty"
elif [[ $DESKTOP == "3" ]] then
      pacman -S plasma-desktop dolphin dolphin-plugins ark kitty kitty-shell-integration kitty-terminfo btop starship yazi plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm xdg-utils xdg-user-dirs-gtk touchegg breeze-gtk pamac-tray-icon-plasma qalculate xdg-desktop-portal-gtk xdg-desktop-portal-kde f2fs-tools traceroute gufw ktorrent merkuro skanlite kdenlive audacity vlc mplayer ffmpegthumbs video-downloader shutter-encoder-bin kamoso flameshot gthumb gimp xournalpp proton-vpn-gtk-app bookworm partitionmanager gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs-lts-iron npm yarn python-pip pyenv android-tools vala tk filezilla brave-bin zen-browser-bin downgrade dpkg vscodium postman-bin xclip python-xlib xampp docker flatpak bibata-cursor-theme --noconfirm --needed
      pacman -S yay xdg-terminal-exec-git ollama proton-vpn-gtk-app libappindicator-gtk3 gnome-shell-extension-appindicator papirus-folders ventoy-bin appimagelauncher telegram-desktop zsh-theme-powerlevel10k-git --noconfirm --needed
      pacman -S ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-dejavu-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family noto-fonts noto-fonts-emoji ibus-typing-booster ttf-dejavu ttf-hanazono ttf-ms-fonts ttf-font-awesome awesome-terminal-fonts powerline-fonts --noconfirm --needed
# pamac install megasync-bin crow-translate mailspring-bin papirus-folders-nordic --no-confirm

    systemctl enable sddm touchegg
    export TERM="kitty"
    export TERMINAL="kitty"
    sed -i 's/Current=/Current=breeze/' /usr/lib/sddm/sddm.conf.d/default.conf

else
    echo "Desktop Will Not be Installed"
fi

echo "================================================================="
echo "==                 Sound, Bluetooth, Printer Drivers            =="
echo "================================================================="

if [[ $SOUNDBLUETOOTHPRINTER == "y" ]] then
    pacman -S bluez bluez-utils bluez-libs bluez-hid2hci cups pipewire pipewire-audio pipewire-alsa pipewire-pulse gst-plugin-pipewire libpipewire gst-libav gst-plugins-base gst-plugins-bad gst-plugins-ugly gst-plugins-good pavucontrol mediainfo ffmpeg openh264 --noconfirm --needed

    systemctl enable bluetooth cups

else
    "Sound, Bluetooth, Printer Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==                   GRAPGIC CARD INSTALLATION                 =="
echo "================================================================="

if [[ $GRAPHIC == "1" ]] then
    pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland xf86-video-amdgpu --noconfirm --needed
    
elif [[ $GRAPHIC == "2" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland xf86-video-intel --noconfirm --needed
    
elif [[ $GRAPHIC == "3" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland xf86-video-amdgpu xf86-video-intel --noconfirm --needed
 
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "1" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-amdgpu --noconfirm --needed
      pacman -S nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
      sed -i 's/MODULES=()/MODULES=(amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P

elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "2" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-amdgpu --noconfirm --needed
      pacman -S nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
  
      sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
      sed -i 's/MODULES=()/MODULES=(amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P

elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "1" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-intel --noconfirm --needed
      pacman -S nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
  
      sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
      sed -i 's/MODULES=()/MODULES=(i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
 
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "2" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-intel --noconfirm --needed
      pacman -S nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm -needed
 
      sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
      sed -i 's/MODULES=()/MODULES=(i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P

else
    "Graphic Card Will Not be Installed"
fi

echo "================================================================="
echo "==                 Power Optimization Tools                    =="
echo "================================================================="

if [[ $POWER == "y" ]] then
    pacman -S auto-cpufreq envycontrol --noconfirm --needed
#  pamac install auto-epp --no-confirm

    systemctl enable --now auto-cpufreq

else
    "Power Optimization Tools Will be Not Installed"
fi

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

if [[ $DATABASE == "y" ]] then
    pacman -S postgresql mysql sqlite --noconfirm --needed
# pamac install mssql-server --no-confirm

else
    "Database Will Mot be Installed"
fi

echo "================================================================="
echo "==                      GAMING INSTALLATION                    =="
echo "================================================================="

if [[ $GAMING == "y" ]] then
    pacman -S giflib glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation wine wine-gecko wine-mono winetricks vulkan-tools mesa-utils lib32-mesa-utils --noconfirm --needed
    pacman -S gamescope heroic-games-launcher lutris steam  --noconfirm --needed

else
    "Gaming Apps and Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==                        Virtualbox                           =="
echo "================================================================="

if [[ $VBOX == "1" ]] then
    pacman -S virtualbox virtualbox-host-modules-arch virtualbox-guest-iso virtualbox-guest-utils --noconfirm --needed

elif [[ $VBOX == "2" ]] then
      pacman -S virtualbox virtualbox-host-modules-lts virtualbox-guest-iso virtualbox-guest-utils --noconfirm --needed

else
    "Virtualbox Will Not be Intalled"
fi

echo "================================================================="
echo "==           Plymouth Installation and Congratulations         =="
echo "================================================================="

if [[ $PLYMOUTH == "y" ]] then
    pacman -S plymouth --noconfirm --needed
 
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet zswap.enabled=0"//GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash udev.log_priority=3 zswap.enabled=0"/' /etc/default/grub
    sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P

else
    "Plymouth Will Mot be Installed"
fi

echo "================================================================="
echo "==            Timeshift and Snapshot Configuration             =="               
echo "================================================================="

if [[ $FILESYSTEM == "1" ]] then
    pacman -S grub-btrfs btrfs-progs timeshift timeshift-autosnap --noconfirm --needed
 
    systemctl enable grub-btrfsd

else
    pacman -S timeshift --noconfirm --needed
fi

REALEND


arch-chroot /mnt sh next.sh

echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="

sleep 10
reboot
