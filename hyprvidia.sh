#!/bin/bash

# Function to display messages
msg() {
    echo -e "\e[1;32m$1\e[0m"
}

# Function to display error messages
err() {
    echo -e "\e[1;31m$1\e[0m" >&2
}

# Must run as root
if [[ $EUID -ne 0 ]]; then
   err "This script must be run as root. Use sudo or switch to the root user."
   exit 1
fi

msg "Updating the system..."
pacman -Syu --noconfirm

msg "Removing Nouveau drivers..."
pacman -Rs --noconfirm xf86-video-nouveau mesa lib32-mesa || true

msg "Detecting NVIDIA GPU..."
GPU_MODEL=$(lspci | grep -i 'vga' | grep -i 'nvidia')
if [[ -z "$GPU_MODEL" ]]; then
    err "No NVIDIA GPU detected. Aborting."
    exit 1
else
    msg "Found NVIDIA GPU: $GPU_MODEL"
fi

msg "Installing proprietary NVIDIA drivers and supporting packages..."
pacman -S --noconfirm \
    linux-headers \
    nvidia-dkms \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-settings \
    libva \
    libva-nvidia-driver-git \
    egl-wayland \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader

msg "Creating Nouveau blacklist..."
echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/nouveau_blacklist.conf

msg "Adding NVIDIA modules to mkinitcpio.conf..."
sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

msg "Creating nvidia-drm modeset config..."
echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia.conf

msg "Generating custom initramfs..."
mkinitcpio -P

msg "Checking GRUB for nvidia_drm.modeset=1..."
if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
    msg "Updated GRUB_CMDLINE_LINUX_DEFAULT with nvidia_drm.modeset=1"
    grub-mkconfig -o /boot/grub/grub.cfg
fi

msg "NVIDIA setup for Hyprland is complete! Reboot your system to apply everything."
