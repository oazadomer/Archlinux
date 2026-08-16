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
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

pacman-key --init; pacman-key --populate archlinux; pacman -Sy archlinux-keyring --noconfirm --needed
timedatectl set-ntp true

reflector --latest 6 --sort rate --save /etc/pacman.d/mirrorlist
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/ParallelDownloads = 5/ParallelDownloads = 3/' /etc/pacman.conf
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
echo "# Please Choose The Kernel:"
echo "1. Linux"
echo "2. Linux-lts"
read KERNEL
echo "="
echo "# Please Choose The Bootloader:"
echo "1. GRUB"
echo "2. rEFInd"
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
echo "1. GNOME"
echo "2. KDE"
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
echo "# Do You Want To Install Office?"
echo "1. OnlyOffice"
echo "2. WPS-Office"
echo "n. Don't Install"
read OFFICE
echo "="
echo "Do You Want To Install Programs Like:"
echo "Media Player, Image and Video Editor"
echo "E-Mail, Chat, Vscode, Fonts, ProtonVPN, etc"
echo "y"
echo "n"
read PROGRAMS
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

echo "================================================================="
echo "==            Formating And Mounting The Filesystem            =="
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
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [[ $KERNEL == "1" ]]; then
    retry_command pacstrap /mnt base base-devel linux linux-firmware linux-headers bash-completion gvim git curl perl make cmake wget gcc gawk reflector rsync networkmanager mtools dosfstools ntfs-3g cronie acpid touchegg                           

elif [[ $KERNEL == "2" ]]; then
    retry_command pacstrap /mnt base base-devel linux-lts linux-firmware linux-lts-headers bash-completion gvim git curl perl make cmake wget gcc gawk reflector rsync networkmanager mtools dosfstools ntfs-3g cronie acpid touchegg                                          
fi

genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh

echo "$HOSTNAME:$HOSTNAMEPASSWORD" | chpasswd
useradd -mG wheel,audio,video,optical,storage $USERNAME
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

systemctl enable NetworkManager fstrim.timer reflector.timer acpid touchegg

echo "================================================================="
echo "==                  Installing Bootloader                      =="
echo "================================================================="

if [[ $BOOTLOADER == "1" ]]; then
    retry_command pacman -S grub efibootmgr --noconfirm --needed
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
    
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=btrfs loglevel=3 quiet udev.log_priority=3"/' /etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    
    grub-mkconfig -o /boot/grub/grub.cfg

else [[ $BOOTLOADER == "2" ]]; then 
      retry_command pacman -S refind efibootmgr --noconfirm --needed
      refind-install --usedefault "${EFI}"

fi   

echo "================================================================="
echo "==                    Enable Multilib Repo                     =="
echo "================================================================="

 pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
 pacman-key --lsign-key 3056513887B78AEB
 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm --needed
 pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm --needed
 
 sed -i 's/^#Color/Color/' /etc/pacman.conf
 sed -i '/Color/a ILoveCandy' /etc/pacman.conf
 sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
 sed -i 's/ParallelDownloads = 5/ParallelDownloads = 2/' /etc/pacman.conf
 
 echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
 echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf
 
 retry_command pacman -Sy; pacman -S pamac --noconfirm --needed
 
 sed -i 's/^#EnableAUR/EnableAUR/' /etc/pamac.conf
 sed -i 's/^#EnableFlatpak/EnableFlatpak/' /etc/pamac.conf      
 sed -i 's/MaxParallelDownloads = 4/MaxParallelDownloads = 2/' /etc/pamac.conf
 
 retry_command pacman -Syu --noconfirm
 retry_command pamac update --no-confirm

echo "================================================================="
echo "==                            CPU                              =="
echo "================================================================="

if [[ $CPU == "1" ]]; then
    retry_command pacman -S amd-ucode --noconfirm --needed

elif [[ $CPU == "2" ]]; then
    retry_command pacman -S intel-ucode --noconfirm --needed
fi

echo "================================================================="
echo "==                    DESKTOP ENVIRONMENT                      =="
echo "================================================================="

if [[ $DESKTOP == "1" ]]; then
      retry_command pacman -S wayland wayland-utils wayland-protocols glfw-wayland xorg-xwayland xorg-xlsclients --noconfirm --needed
      retry_command pacman -S gnome-shell gnome-control-center gnome-menus ghostty yazi starship gedit gedit-plugins gnome-bluetooth gnome-themes-extra gnome-keyring power-profiles-daemon gnome-backgrounds gnome-tweaks gnome-online-accounts 
      retry_command pacman -S catppuccin-cursors-mocha bibata-cursor-theme transmission-gtk gnome-screenshot gnome-calculator gnome-calendar simple-scan shotwell gparted gnome-browser-connector btop file-roller gdm xdg-utils xdg-user-dirs-gtk f2fs-tools traceroute gufw xdg-desktop-portal-gtk xdg-desktop-portal-gnome gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs 7zip xz unrar unzip lzop gdb mtpfs nodejs-lts-jod npm yarn ripgrep python-pip pyenv android-tools vala tk brave-origin-bin dpkg xclip python-xlib yay --noconfirm --needed
 
      export TERM="ghostty"
      export TERMINAL="ghostty"
      systemctl enable gdm ufw
    
elif [[ $DESKTOP == "2" ]]; then
      retry_command pacman -S wayland wayland-utils wayland-protocols glfw-wayland xorg-xwayland xorg-xlsclients qt5-wayland --noconfirm --needed
      retry_command pacman -S plasma-desktop dolphin dolphin-plugins ark kate plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen btop sddm sddm-kcm xdg-utils xdg-user-dirs-gtk breeze-gtk pamac-tray-icon-plasma xdg-desktop-portal-gtk xdg-desktop-portal-kde kitty kitty-shell-integration kitty-terminfo yazi starship f2fs-tools traceroute gufw 
      retry_command pacman -S catppuccin-cursors-mocha bibata-cursor-theme qalculate merkuro skanlite qbittorrent ffmpegthumbs kamoso flameshot gthumb gparted gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs 7zip xz unrar unzip lzop gdb mtpfs nodejs-lts-jod npm yarn python-pip pyenv android-tools vala tk brave-origin-bin dpkg vscodium xclip python-xlib kvantum kvantum-qt5 yay --noconfirm --needed
      
      export TERM="kitty"
      export TERMINAL="kitty"
      systemctl enable sddm ufw
      sed -i 's/Current=/Current=breeze/' /usr/lib/sddm/sddm.conf.d/default.conf
    
else
    echo "Desktop Will Not be Installed"
fi

# SSSD
cat <<EOF > /etc/sssd/sssd.conf
[sssd]
domains = example.com
config_file_version = 2
services = nss, pam

[domain/example.com]
id_provider = ldap
ldap_uri = ldap://your-ldap-server
ldap_search_base = dc=example,dc=com
EOF

sudo chmod 600 /etc/sssd/sssd.conf
sudo chown root:root /etc/sssd/sssd.conf

echo "================================================================="
echo "==                 Sound, Bluetooth, Printer Drivers            =="
echo "================================================================="

if [[ $SOUNDBLUETOOTHPRINTER == "y" ]]; then
    retry_command pacman -S bluez bluez-utils bluez-libs bluez-hid2hci cups pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack gst-plugin-pipewire libpipewire gst-libav gst-plugins-base gst-plugins-bad gst-plugins-ugly gst-plugins-good pavucontrol mediainfo ffmpeg openh264 --noconfirm --needed

    systemctl enable bluetooth cups

else
   echo "Sound, Bluetooth, Printer Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==                   GRAPHIC CARD INSTALLATION                 =="
echo "================================================================="

if [[ $GRAPHIC == "1" ]]; then
    retry_command pacman -S xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
    
elif [[ $GRAPHIC == "2" ]]; then
      retry_command pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
    
elif [[ $GRAPHIC == "3" ]]; then
      retry_command pacman -S xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
      retry_command pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
 
elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "1" ]]; then
      retry_command pacman -S xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/MODULES=.*/MODULES=(btrfs amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
      
      if [[ $BOOTLOADER == "1" ]]; then   
         sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
         grub-mkconfig -o /boot/grub/grub.cfg
       
      fi

elif [[ $GRAPHIC == "4" ]] && [[ $KERNEL == "2" ]]; then
      retry_command pacman -S xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/MODULES=.*/MODULES=(btrfs amdgpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
      
      if [[ $BOOTLOADER == "1" ]]; then
        sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
       
      fi
      
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "1" ]]; then
      retry_command pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm --needed

      sed -i 's/MODULES=.*/MODULES=(btrfs i915 nvidia nvidia_modeset nvidia_drm nvidia_uvm)/' /etc/mkinitcpio.conf
      mkinitcpio -P
       
      if [[ $BOOTLOADER == "1" ]]; then 
       sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 rd.driver.blacklist=nouveau modprob.blacklist=nouveau"/' /etc/default/grub
       grub-mkconfig -o /boot/grub/grub.cfg
       
      fi
    
elif [[ $GRAPHIC == "5" ]] && [[ $KERNEL == "2" ]]; then
      retry_command pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel --noconfirm --needed
      retry_command pacman -S egl-wayland nvidia-lts nvidia-prime nvidia-utils nvidia-dkms lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat --noconfirm -needed

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
echo "==                          Programs                           =="
echo "================================================================="

if [[ $PROGRAMS == "y" ]]; then
    retry_command pacman -S gimp audacity audacious mplayer mpd rmpc vlc
    retry_command pacman -S vscodium mailspring envycontrol ulauncher acpi ferdium-bin xdg-terminal-exec-git proton-vpn-gtk-app libappindicator-gtk3 ventoy-bin appimagelauncher --noconfirm --needed
    retry_command pacman -S ttf-firacode-nerd ttf-ubuntu-font-family ttf-dejavu noto-fonts noto-fonts-emoji ibus-typing-booster ttf-hanazono ttf-ms-fonts --noconfirm --needed
#    retry_command pamac install megasync-bin crow-translate --no-confirm

    if [[ $DESKTOP == "1" ]]; then
    retry_command pacman -S shotcut

    elif [[ $DESKTOP == "2" ]]; then
    retry_command pacman -S kdenlive

else
   echo "Programs Will Not be Installed"
fi

echo "================================================================="
echo "==                      OFFICE INSTALLATION                    =="
echo "================================================================="

if [[ $OFFICE == "1" ]]; then
    retry_command pacman -S onlyoffice-bin --noconfirm --needed

elif [[ $OFFICE == "2" ]]; then
      retry_command pacman -S wps-office wps-office-all-dicts-win-languages libtiff5 --noconfirm --needed

else
   echo "Office Will Not be Installed"
fi

echo "================================================================="
echo "==                           DATABASE                          =="
echo "================================================================="

if [[ $DATABASE == "y" ]]; then
    retry_command pacman -S postgresql mysql sqlite --noconfirm --needed
#    retry_command pamac install dbgate-bin

else
   echo "Database Will Not be Installed"
fi

echo "================================================================="
echo "==                      GAMING INSTALLATION                    =="
echo "================================================================="

if [[ $GAMING == "y" ]]; then
    retry_command pacman -S lib32-libudev0-shim giflib glfw gst-plugins-base-libs lib32-alsa-plugins lib32-giflib lib32-gst-plugins-base-libs lib32-gtk3 lib32-libjpeg-turbo lib32-libva lib32-mpg123 lib32-ocl-icd lib32-opencl-icd-loader lib32-openal libjpeg-turbo libva libxslt mpg123 opencl-icd-loader openal ttf-liberation wine wine-gecko wine-mono winetricks vulkan-tools mesa-utils lib32-mesa-utils --noconfirm --needed
    retry_command pacman -S heroic-games-launcher steam --noconfirm --needed

else
   echo "Gaming Apps and Drivers Will Not be Installed"
fi

echo "================================================================="
echo "==            Timeshift and Snapshot Configuration             =="               
echo "================================================================="

if [[ $BOOTLOADER == "1" ]]; then
    retry_command pacman -S inotify-tools grub-btrfs btrfs-progs timeshift timeshift-autosnap --noconfirm --needed
 
    systemctl enable grub-btrfsd
    
else
    retry_command pacman -S timeshift --noconfirm --needed
fi

echo "================================================================="
echo "==                     Zram Configuration                      =="               
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
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="

trap 'printf "\nReboot cancelled.\n"; exit 1' INT

for ((i=10; i>0; i--)); do
    printf "\rRebooting in %d seconds. Press Ctrl+C to cancel.   " "$i"
    sleep 1
done

printf "\rRebooting now...                              \n"
sudo reboot

