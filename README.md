Archlinux Installation Script


1- Connect to the internet

2- Download the script by typing: curl https://raw.githubusercontent.com/oazadomer/Archlinux/main/archlinux.sh -o archlinux.sh

3- Run the script by typing: sh archlinux.sh

4- Partition your Drive to two EFI and ROOT

5- İf you will gaming with Cachyos Kernel and open Nvidia then in GPU option go just with integrated once 

6- How to use Envycontrol:
glxinfo | grep "renderer"
sudo envycontrol --switch nvidia
sudo envycontrol --switch integrated
sudo envycontrol --switch hybrid
