#!/usr/bin/env bash

echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

pacman-key --init; pacman-key --populate archlinux; pacman -Sy archlinux-keyring --noconfirm --needed
timedatectl set-ntp true
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy

echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo "="
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "# Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ):"
read DISK
echo "="
echo "Manual Partitioning..."
cfdisk "$DISK"
echo "="
echo "# Please Enter EFI Partition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ):"
read EFI
echo "="
echo "# Please Enter Root Partition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ):"
read ROOT
echo "="
echo "# Please Choose File System:"
echo "1. Btrfs"
echo "2. Ext4"
read FILESYSTEM
echo "="
echo "# Please Choose The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "# Please Choose The Bootloader:"
echo "1. GRUB"
echo "2. SYSTEMD"
read BOOTLOADER
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
echo "# Do You Want to Install Database?"
echo "Postgresql, Mysql, Sqlite"
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
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers gvim efibootmgr zsh git python gcc make cmake less wget curl libaio reflector rsync networkmanager usb_modeswitch wireless_tools smartmontools mtools net-tools dosfstools efitools nfs-utils nilfs-utils exfatprogs ntfs-3g ntp openssh cronie pacman-contrib pkgfile rebuild-detector mousetweaks usbutils ncdu os-prober                                      
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers gvim efibootmgr zsh git python gcc make cmake less wget curl libaio reflector rsync networkmanager usb_modeswitch wireless_tools smartmontools mtools net-tools dosfstools efitools nfs-utils nilfs-utils exfatprogs ntfs-3g ntp openssh cronie pacman-contrib pkgfile rebuild-detector mousetweaks usbutils ncdu os-prober                                                
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
echo "==                  Installing Bootloader                      =="
echo "================================================================="

if [[ $BOOTLOADER == "1" ]] then
   pacman -S grub
   grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux

   sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=5/' /etc/default/grub
   sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=btrfs loglevel=3 quiet splash udev.log_priority=3"/' /etc/default/grub
   sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
   sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

   grub-mkconfig -o /boot/grub/grub.cfg

else 
   bootctl install
   sed -i 's/^#timeout 3/timeout 5/' /boot/loader/loader.conf
   sed -i 's/^default/default arch-*/' /boot/loader/loader.conf

   echo -e "\ntitle   Arch linux\nlinux   /vnlinuz-linux-lts" >> /boot/loader/entries/arch.conf
   echo -e "\ninitrd   /initramfs-linux.img\noptions root=/dev/$ROOT" rw rootfstype=btrfs quiet splash>> /boot/loader/entries/arch.conf
fi   

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
    pacman -S cinnamon nemo nemo-fileroller kitty kitty-shell-integration kitty-terminfo btop starship yazi gnome-themes-extra gnome-keyring blueman lightdm lightdm-slick-greeter xdg-utils xdg-user-dirs-gtk numlockx touchegg f2fs-tools traceroute gufw xdg-desktop-portal-gtk transmission-gtk gnome-calculator gnome-calendar gnome-online-accounts simple-scan kdenlive audacity audacious vlc mplayer video-downloader shutter-encoder-bin snapshot gnome-screenshot shotwell gimp xournalpp proton-vpn-gtk-app gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla mintlocale lightdm-settings brave-bin downgrade dpkg vscodium postman-bin xclip python-xlib xampp docker flatpak bibata-cursor-theme kvantum --noconfirm --needed
    pacman -S spotify whatsie-git xpad yay xdg-terminal-exec-git ollama proton-vpn-gtk-app libappindicator-gtk3 gnome-shell-extension-appindicator papirus-folders ventoy-bin appimagelauncher telegram-desktop --noconfirm --needed
    pacman -S ttf-jetbrains-mono-nerd ttf-cascadia-mono-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family ttf-dejavu noto-fonts noto-fonts-emoji ibus-typing-booster ttf-hanazono ttf-ms-fonts awesome-terminal-fonts --noconfirm --needed
  # pamac install thorium-browser-bin megasync-bin crow-translate mailspring-bin acetoneiso local-by-flywheel-bin stacer-bin papirus-folders-nordic --no-confirm
    
    export TERM="kitty"
    export TERMINAL="kitty"
    systemctl enable lightdm
    sed -i 's/^#greeter-session=/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf

elif [[ $DESKTOP == "2" ]] then
      pacman -S gnome-shell gnome-control-center kitty kitty-shell-integration kitty-terminfo btop starship yazi gnome-bluetooth gnome-themes-extra gnome-keyring power-profiles-daemon gnome-backgrounds gnome-tweaks gnome-menus gnome-screenshot gnome-online-accounts nautilus file-roller gdm xdg-utils xdg-user-dirs-gtk touchegg f2fs-tools traceroute gufw xdg-desktop-portal-gtk xdg-desktop-portal-gnome transmission-gtk gnome-calculator gnome-calendar simple-scan kdenlive audacity audacious vlc mplayer video-downloader shutter-encoder-bin snapshot shotwell gimp xournalpp proton-vpn-gtk-app gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn ripgrep python-pip pyenv android-tools vala tk filezilla brave-bin downgrade dpkg vscodium postman-bin xclip python-xlib xampp docker flatpak bibata-cursor-theme kvantum --noconfirm --needed
      pacman -S spotify whatsie-git xpad yay xdg-terminal-exec-git ollama proton-vpn-gtk-app libappindicator-gtk3 gnome-shell-extension-appindicator papirus-folders ventoy-bin appimagelauncher telegram-desktop --noconfirm --needed
      pacman -S ttf-jetbrains-mono-nerd ttf-cascadia-mono-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family ttf-dejavu noto-fonts noto-fonts-emoji ibus-typing-booster ttf-hanazono ttf-ms-fonts awesome-terminal-fonts --noconfirm --needed
   # pamac install thorium-browser-bin megasync-bin crow-translate mailspring-bin acetoneiso local-by-flywheel-bin stacer-bin papirus-folders-nordic --no-confirm
 
    export TERM="kitty"
    export TERMINAL="kitty"
    
elif [[ $DESKTOP == "3" ]] then
      pacman -S plasma-desktop dolphin dolphin-plugins ark kitty kitty-shell-integration kitty-terminfo btop starship yazi plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm xdg-utils xdg-user-dirs-gtk touchegg breeze-gtk pamac-tray-icon-plasma qalculate xdg-desktop-portal-gtk xdg-desktop-portal-kde f2fs-tools traceroute gufw ktorrent merkuro skanlite kdenlive audacity vlc mplayer ffmpegthumbs video-downloader shutter-encoder-bin kamoso flameshot gthumb gimp xournalpp proton-vpn-gtk-app bookworm partitionmanager gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs xz unrar unzip lzop gdb mtpfs php nodejs npm yarn python-pip pyenv android-tools vala tk filezilla brave-bin downgrade dpkg vscodium postman-bin xclip python-xlib xampp docker flatpak bibata-cursor-theme --noconfirm --needed
      pacman -S spotify whatsie-git xpad yay xdg-terminal-exec-git ollama proton-vpn-gtk-app libappindicator-gtk3 gnome-shell-extension-appindicator papirus-folders ventoy-bin appimagelauncher telegram-desktop --noconfirm --needed
      pacman -S ttf-jetbrains-mono-nerd ttf-cascadia-mono-nerd ttf-firacode-nerd ttf-hack-nerd ttf-ubuntu-font-family ttf-dejavu noto-fonts noto-fonts-emoji ibus-typing-booster ttf-hanazono ttf-ms-fonts awesome-terminal-fonts --noconfirm --needed
   # pamac install thorium-browser-bin megasync-bin crow-translate mailspring-bin acetoneiso local-by-flywheel-bin stacer-bin papirus-folders-nordic --no-confirm

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
     
      if [[ $BOOTLOADER == "1" ]] then   
         sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
         sed -i 's/MODULES=()/MODULES=(amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
         grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
      fi

elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "2" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-amdgpu --noconfirm --needed
      pacman -S nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed

      if [[ $BOOTLOADER == "1" ]] then
        sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
        sed -i 's/MODULES=()/MODULES=(amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
        grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
      fi
      
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "1" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-intel --noconfirm --needed
      pacman -S nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed
     
     if [[ $BOOTLOADER == "1" ]] then 
      sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
      sed -i 's/MODULES=()/MODULES=(i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
    fi
    
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "2" ]] then
      pacman -S xorg-server xorg-xkill xorg-xinput xorg-xinit xf86-input-libinput libwnck3 mesa-utils libinput xorg-xwayland xorg-xlsclients wayland wayland-utils wayland-protocols glfw-wayland egl-wayland xf86-video-intel --noconfirm --needed
      pacman -S nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm -needed

    if [[ $BOOTLOADER == "1" ]] then
      sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
      sed -i 's/MODULES=()/MODULES=(i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P
    fi
    
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
    pacman -S lib32-libudev0-shim giflib glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation wine wine-gecko wine-mono winetricks vulkan-tools mesa-utils lib32-mesa-utils --noconfirm --needed
    pacman -S heroic-games-launcher steam --noconfirm --needed

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
    "Virtualbox Will Not be Installed"
fi

echo "================================================================="
echo "==           Plymouth Installation and Congratulations         =="
echo "================================================================="

if [[ $PLYMOUTH == "y" ]] && [[ BOOTLOADER == "1" ]] then
    pacman -S plymouth --noconfirm --needed
    sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap block filesystems fsck)/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap block filesystems fsck)/' /etc/mkinitcpio.conf
    grub-mkconfig -o /boot/grub/grub.cfg; mkinitcpio -P

elif [[ $PLYMOUTH == "y" ]] && [[ BOOTLOADER == "2" ]] then
    pacman -S plymouth
    sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap block filesystems fsck)/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap block filesystems fsck)/' /etc/mkinitcpio.conf

else
   "Plymouth Will Not be Installed"
fi

echo "================================================================="
echo "==            Timeshift and Snapshot Configuration             =="               
echo "================================================================="

if [[ $FILESYSTEM == "1" ]] && [[ BOOTLOADER == "1" ]] then
    pacman -S inotify-tools grub-btrfs btrfs-progs timeshift timeshift-autosnap --noconfirm --needed
 
    systemctl enable grub-btrfsd

else
    pacman -S timeshift --noconfirm --needed
fi

echo "================================================================="
echo "==                     Zram Configuration                      =="               
echo "================================================================="

pacman -S zram-generator  --noconfirm --needed

if [[ $BOOTLOADER == "1" ]] then
   sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash udev.log_priority=3"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash udev.log_priority=3 zswap.enabled=0"/' /etc/default/grub
   echo -e "\n[zram0]\nzram-size=ram" >> /usr/lib/systemd/zram-generator.conf
   echo -e "\ncompression-algorithm=zstd\nswap-priority=60\n" >> /usr/lib/systemd/zram-generator.conf
else 
   echo -e "\n[zram0]\nzram-size=ram" >> /usr/lib/systemd/zram-generator.conf
   echo -e "\ncompression-algorithm=zstd\nswap-priority=60\n" >> /usr/lib/systemd/zram-generator.conf
fi

systemctl daemon-reload
systemctl start /dev/zram0


REALEND


arch-chroot /mnt sh next.sh

echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="

sleep 10
reboot
