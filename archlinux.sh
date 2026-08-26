#!/usr/bin/env bash

# Retry function
retry_command() {
    local retries=5
    local count=0
    local delay=5
    local cmd="$@"

    while [[ $count -lt $retries ]]; do
        echo "Attempt $((count+1)) of $retries: Running '$cmd'..."
        eval "$cmd" && return 0
        count=$((count+1))
        echo "Command failed. Retrying in $delay seconds..."
        sleep $delay
    done
    echo "Command failed after $retries attempts."
    return 1
}

echo "================================================================="
echo "==         WELCOME TO THE ARCH LINUX INSTALLATION SCRIPT       =="
echo "================================================================="

pacman-key --init; pacman-key --populate archlinux; pacman -Sy archlinux-keyring --noconfirm --needed
timedatectl set-ntp true

reflector --latest 6 --sort rate --save /etc/pacman.d/mirrorlist
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/ParallelDownloads = 5/ParallelDownloads = 3/' /etc/pacman.conf
pacman -Sy

echo "================================================================="
echo "==                    PARTITIONING THE DRIVE                   =="
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
echo "# Enter EFI Partition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ):"
read EFI
echo "="
echo "# Enter Root Partition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ):"
read ROOT
echo "="
echo "# Choose The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "# Choose The Bootloader:"
echo "1. GRUB"
echo "2. rEFInd"
read BOOTLOADER
echo "="
echo "# Enter Your hostname:"
read HOSTNAME
echo "="
echo "# Enter Your hostname password:"
read HOSTNAMEPASSWORD
echo "="
echo "# Enter Your username:"
read USERNAME
echo "="
echo "# Enter Your username password:"
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
echo "# choose your CPU"
echo "1. AMD"
echo "2. Intel"
read CPU
echo "="
echo "# Choose Your Desktop Environment:"
echo "1. GNOME"
echo "2. KDE"
echo "3. HYPRLAND + NOCTALIA"
echo "n. NO DESKTOP"
read DESKTOP
echo "="
echo "# Do You Want To Install Printer Drivers?"
echo "y"
echo "n"
read PRINTER
echo "="
echo "# Choose Your Graphic Card:"
echo "1. AMD"
echo "2. INTEL"
echo "3. AMD and INTEL"
echo "4. AMD and NVIDIA"
echo "5. INTEL and NVIDIA"
echo "n. Don't install"
read GRAPHIC
echo "="
echo "Do You Want To Install Programs Like:"
echo "Image and Video Editor, Mailspring, ProtonVPN"
echo "Megasync, Crow Translater, ferdium ...etc"
echo "y"
echo "n"
read PROGRAMS
echo "="
echo "# Do You Want To Install Office?"
echo "1. OnlyOffice"
echo "2. WPS-Office"
echo "n. Don't Install"
read OFFICE
echo "="
echo "# Do You Want to Install Database?"
echo "Postgresql, Mysql, Sqlite, dbgate"
echo "y"
echo "n"
read DATABASE
echo "="
echo "# Will you Gaming?"
echo "y"
echo "n"
read GAMING
echo "="
echo"# Do You Want to Install Power Management Tools?"
echo "y"
echo "a, ASUS ROG, TUF"
echo "n"
read POWER
echo "="

echo "================================================================="
echo "==           FORMATTING AND MOUNTING THE FILESYSTEM            =="
echo "================================================================="

   mkfs.vfat -F32 -n "ARCH" "${EFI}"
   mkfs.btrfs -f -L "ROOT" "${ROOT}"
   mount -t btrfs "${ROOT}" /mnt
   btrfs su cr /mnt/@
   btrfs su cr /mnt/@snapshots
   umount /mnt
   mount -o noatime,compress=zstd,subvol=@ "${ROOT}" /mnt
   mkdir -p /mnt/{boot,.snapshots}
   mount -o noatime,compress=zstd,subvol=@snapshots "${ROOT}" /mnt/.snapshots
   mount -t vfat "${EFI}" /mnt/boot

echo "================================================================="
echo "==                    INSTALLING ARCH LINUX                    =="
echo "================================================================="

if [[ $KERNEL == "1" ]]; then
    retry_command pacstrap /mnt base base-devel linux linux-firmware linux-headers bash-completion neovim git curl perl make cmake wget gcc gawk reflector rsync networkmanager mtools dosfstools ntfs-3g cronie acpid touchegg openssh         

elif [[ $KERNEL == "2" ]]; then
      retry_command pacstrap /mnt base base-devel linux-lts linux-firmware linux-lts-headers bash-completion neovim git curl perl make cmake wget gcc gawk reflector rsync networkmanager mtools dosfstools ntfs-3g cronie acpid touchegg openssh                               
fi

genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh

echo "$HOSTNAME:$HOSTNAMEPASSWORD" | chpasswd
useradd -mG wheel,audio,video,optical,storage $USERNAME
echo "$USERNAME:$USERNAMEPASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "================================================================="
echo "==              SETTING LANGUAGE AND SETTING LOCALE            =="
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
echo "==        ENABLING NETWORK SERVICE, FSTRIM ACIP, TOUCHEGG      =="
echo "================================================================="

systemctl enable NetworkManager fstrim.timer reflector.timer acpid touchegg ssh

echo "================================================================="
echo "==                  INSTALLING BOOTLOADER                      =="
echo "================================================================="

if [[ $BOOTLOADER == "1" ]]; then
    retry_command pacman -S grub efibootmgr --noconfirm --needed
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=btrfs loglevel=3 quiet udev.log_priority=3"/' /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    
    grub-mkconfig -o /boot/grub/grub.cfg

elif [[ $BOOTLOADER == "2" ]]; then
      retry_command pacman -S refind efibootmgr --noconfirm --needed
      refind-install      # --usedefault "${EFI}"
fi   

echo "================================================================="
echo "==             ENABLING MULTILIB & COMMUNITY REPOS             =="
echo "================================================================="

pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keys.openpgp.org
pacman-key --lsign-key 3056513887B78AEB
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm --needed
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm --needed

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i '/Color/a ILoveCandy' /etc/pacman.conf
sed -i 's/^#*\s*ParallelDownloads\s*=\s*.*/ParallelDownloads = 2/' /etc/pacman.conf

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

retry_command pacman -Sy --noconfirm

echo "================================================================="
echo "==                 INSTALLING CPU DRIVERS                      =="
echo "================================================================="

if [[ $CPU == "1" ]]; then
    retry_command pacman -S amd-ucode --noconfirm --needed

elif [[ $CPU == "2" ]]; then
      retry_command pacman -S intel-ucode --noconfirm --needed
fi

echo "================================================================="
echo "==            INSTALLING DESKTOP ENVIRONMENT                   =="
echo "================================================================="

if [[ $DESKTOP =~ ^[1-3]$ ]]; then
    retry_command pacman -S wayland wayland-utils wayland-protocols glfw-wayland xorg-xwayland xorg-xlsclients libxkbcommon --noconfirm --needed
    retry_command pacman -S xdg-utils xdg-user-dirs-gtk xdg-desktop-portal-gtk xdg-terminal-exec-git --noconfirm --needed
    retry_command pacman -S topgrade zed catppuccin-cursors-mocha gparted f2fs-tools traceroute gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs 7zip xz unrar unzip lzop gdb mtpfs nodejs-lts-krypton npm yarn ripgrep python-pip pyenv android-tools vala tk dpkg tldr ncdu --noconfirm --needed
    retry_command pacman -S ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-ubuntu-font-family ttf-dejavu noto-fonts noto-fonts-emoji ibus-typing-booster ttf-hanazono ttf-ms-fonts --noconfirm --needed
    retry_command pacman -S bluez bluez-utils bluez-libs bluez-hid2hci wireplumber pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack gst-plugin-pipewire libpipewire gst-libav gst-plugins-base gst-plugins-bad gst-plugins-ugly gst-plugins-good pavucontrol mediainfo ffmpeg openh264 --noconfirm --needed
    retry_command pacman -S brave-origin-bin yay gufw audacious mpv mplayer btop superfile starship --noconfirm --needed
    
    systemctl enable bluetooth ufw
fi

if [[ $DESKTOP == "1" ]]; then
    retry_command pacman -S gnome-shell gnome-control-center gnome-menus gnome-bluetooth gnome-themes-extra gnome-keyring power-profiles-daemon gnome-backgrounds gnome-tweaks gnome-online-accounts gnome-browser-connector nautilus sushi ghostty xdg-desktop-portal-gnome file-roller gdm transmission-gtk gnome-screenshot gnome-calculator gnome-calendar simple-scan loupe snapshot --noconfirm --needed
     
    export TERM="ghostty"
    export TERMINAL="ghostty"
    systemctl enable gdm
    
elif [[ $DESKTOP == "2" ]]; then
      retry_command pacman -S plasma-desktop dolphin dolphin-plugins ark plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen sddm sddm-kcm breeze-gtk pamac-tray-icon-plasma xdg-desktop-portal-kde kitty kitty-shell-integration kitty-terminfo qalculate-gtk merkuro skanlite qbittorrent kamoso flameshot gthumb ffmpegthumbs --noconfirm --needed
      retry_command pacman -S qt6-wayland qt5-wayland adwaita-qt6 adwaita-qt5 kvantum kvantum-qt5 --noconfirm --needed

      # 1. Temporarily allow passwordless sudo for the user to prevent the script from hanging
      echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-temp-aur-install
      chmod 440 /etc/sudoers.d/99-temp-aur-install
      
      # 2. Install Noctalia SDDM Greeter from AUR (must be run as the normal user, not root)
      su - "$USERNAME" -c "yay -S sddm-theme-noctalia-git --noconfirm --needed"
      
      # 3. Clean up the temporary sudoers file (restores normal password requirement)
      rm /etc/sudoers.d/99-temp-aur-install
      
      # 4. Configure SDDM to use the Noctalia theme (Arch Linux recommended drop-in method)
      mkdir -p /etc/sddm.conf.d
      echo -e "[Theme]\nCurrent=noctalia" > /etc/sddm.conf.d/noctalia-theme.conf

      export TERM="kitty"
      export TERMINAL="kitty"
      systemctl enable sddm
      
elif [[ $DESKTOP == "3" ]]; then
      retry_command pacman -S noctalia hyprland polkit-gnome hypridle waybar swaync swww hyprlock rofi-wayland udisks2 nwg-look qt5ct grim slurp swappy wl-clipboard cliphist xdg-desktop-portal-hyprland power-profiles-daemon blueman gnome-keyring kitty kitty-shell-integration kitty-terminfo nautilus sushi file-roller sddm simple-scan loupe snapshot gnome-calendar gnome-calculator transmission-gtk --noconfirm --needed
      retry_command pacman -S qt6-wayland qt5-wayland adwaita-qt6 adwaita-qt5 --noconfirm --needed
      
      echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-temp-aur-install
      chmod 440 /etc/sudoers.d/99-temp-aur-install
      su - "$USERNAME" -c "yay -S sddm-theme-noctalia-git --noconfirm --needed"
      rm /etc/sudoers.d/99-temp-aur-install
      
      mkdir -p /etc/sddm.conf.d
      echo -e "[Theme]\nCurrent=noctalia" > /etc/sddm.conf.d/noctalia-theme.conf

      export TERM="kitty"
      export TERMINAL="kitty"
      systemctl enable sddm
      
else
    echo "Desktop Will Not be Installed"
fi

echo "================================================================="
echo "==                INSTALLING PRINTER DRIVERS                   =="
echo "================================================================="

if [[ $PRINTER == "y" ]]; then
    retry_command pacman -S system-config-printer cups cups-pdf --noconfirm --needed
    systemctl enable cups

else
   echo "Printer Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==              INSTALLING GRAPHIC CARD DRIVERS                =="
echo "================================================================="

if [[ $GRAPHIC == "1" ]]; then
    retry_command pacman -S xf86-video-amdgpu mesa rocm-opencl-runtime lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
    
elif [[ $GRAPHIC == "2" ]]; then
      retry_command pacman -S libva-intel-driver intel-compute-runtime libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
    
elif [[ $GRAPHIC == "3" ]]; then
      retry_command pacman -S xf86-video-amdgpu rocm-opencl-runtime mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
      retry_command pacman -S libva-intel-driver intel-compute-runtime libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
 
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "1" ]]; then
      retry_command pacman -S xf86-video-amdgpu rocm-opencl-runtime mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia cuda libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/MODULES=.*/MODULES=(btrfs amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
      
      if [[ $BOOTLOADER == "1" ]]; then   
          sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
          grub-mkconfig -o /boot/grub/grub.cfg
      fi

elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "2" ]]; then
      retry_command pacman -S xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia cuda libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/MODULES=.*/MODULES=(btrfs amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
      
      if [[ $BOOTLOADER == "1" ]]; then
          sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
          grub-mkconfig -o /boot/grub/grub.cfg
      fi
      
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "1" ]]; then
      retry_command pacman -S libva-intel-driver intel-compute-runtime libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia cuda libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/MODULES=.*/MODULES=(btrfs i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
       
      if [[ $BOOTLOADER == "1" ]]; then 
          sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
          grub-mkconfig -o /boot/grub/grub.cfg
      fi
    
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "2" ]]; then
      retry_command pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia cuda libxnvctrl libxcrypt-compat --noconfirm -needed

      sed -i 's/MODULES=.*/MODULES=(btrfs i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
      
      if [[ $BOOTLOADER == "1" ]]; then
          sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
          grub-mkconfig -o /boot/grub/grub.cfg
      fi
    
else
   echo "Graphic Card Will Not be Installed"
fi

echo "================================================================="
echo "==                  INSTALLING PROGRAMS                        =="
echo "================================================================="

if [[ $PROGRAMS == "y" ]]; then
    retry_command pacman -S gimp audacity shutter-encoder-bin --noconfirm --needed
    retry_command pacman -S mailspring acpi ferdium-bin proton-vpn-gtk-app libappindicator-gtk3 ventoy-bin appimagelauncher --noconfirm --needed

    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-temp-aur-install
    chmod 440 /etc/sudoers.d/99-temp-aur-install
    su - "$USERNAME" -c "yay -S megasync-bin crow-translate --noconfirm --needed"
    rm /etc/sudoers.d/99-temp-aur-install

    if [[ $DESKTOP == "1" ]]; then
        retry_command pacman -S shotcut --noconfirm -needed

    elif [[ $DESKTOP =~ ^[2-3]$ ]]; then
          retry_command pacman -S kdenlive --noconfirm --needed
    fi

else
   echo "Programs Will Not be Installed"
fi

echo "================================================================="
echo "==                    INSTALLING OFFICE                        =="
echo "================================================================="

if [[ $OFFICE == "1" ]]; then
    retry_command pacman -S onlyoffice-bin --noconfirm --needed

elif [[ $OFFICE == "2" ]]; then
      retry_command pacman -S wps-office wps-office-all-dicts-win-languages libtiff5 --noconfirm --needed

else
   echo "Office Will Not be Installed"
fi

echo "================================================================="
echo "==                  INSTALLING DATABASE                        =="
echo "================================================================="

if [[ $DATABASE == "y" ]]; then
    retry_command pacman -S postgresql mysql sqlite --noconfirm --needed

    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-temp-aur-install
    chmod 440 /etc/sudoers.d/99-temp-aur-install
    su - "$USERNAME" -c "yay -S dbgate-bin --noconfirm --needed"
    rm /etc/sudoers.d/99-temp-aur-install

    mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

else
   echo "Database Will Not be Installed"
fi

echo "================================================================="
echo "==                INSTALLING GAMING PACKAGES                   =="
echo "================================================================="

if [[ $GAMING == "y" ]]; then
    retry_command pacman -S lib32-libudev0-shim giflib glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation wine wine-gecko wine-mono winetricks vulkan-tools mesa-utils lib32-mesa-utils --noconfirm --needed
    retry_command pacman -S heroic-games-launcher steam --noconfirm --needed

else
   echo "Gaming Apps and Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==            INSTALLING POWER MANAGEMENT TOOLS                =="
echo "================================================================="

if [[ $POWER == "y" ]]; then
    retry_command pacman -S auto-cpufreq envycontrol --noconfirm --needed

    systemctl disable power-profiles-daemon
    systemctl mask power-profiles-daemon
    systemctl enable auto-cpufreq

elif [[ $POWER == "a" ]]; then
      retry_command pacman -S auto-cpufreq supergfxctl rog-control-center asusctl --noconfirm --needed

      systemctl disable power-profiles-daemon
      systemctl mask power-profiles-daemon
      systemctl enable asusd auto-cpufreq supergfxd

      supergfxctl -g integrated
      asusctl -P 80
else
    echo "Power Management Tools Will Not be Installed"
fi

echo "================================================================="
echo "==       INSTALLING TIMESHIFT AND SNAPSHOT CONFIGURATION       =="               
echo "================================================================="

if [[ $BOOTLOADER == "1" ]]; then
    retry_command pacman -S inotify-tools grub-btrfs btrfs-progs timeshift timeshift-autosnap --noconfirm --needed
 
    systemctl enable grub-btrfsd
    
else
    retry_command pacman -S timeshift --noconfirm --needed
fi

echo "================================================================="
echo "==             INSTALLING ZRAM AND CONFIGURATION               =="               
echo "================================================================="

retry_command pacman -S zram-generator  --noconfirm --needed

cat > /etc/systemd/zram-generator.conf << EOF
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
EOF

if [[ $BOOTLOADER == "1" ]]; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=btrfs loglevel=3 quiet splash udev.log_priority=3 rd.udev.log_level=3 zswap.enabled=0"/' /etc/default/grub
   
   grub-mkconfig -o /boot/grub/grub.cfg
fi

REALEND

arch-chroot /mnt sh next.sh

echo "================================================================="
echo "==       INSTALLATION COMPLETE. REBOOTING IN 10 SECONDS...     =="
echo "================================================================="

for ((i=10; i>0; i--)); do
    printf "\rRebooting in %d seconds.   " "$i"
    sleep 1
done

printf "\rRebooting now...\n"
reboot

