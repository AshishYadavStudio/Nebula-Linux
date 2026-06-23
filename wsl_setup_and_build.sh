#!/bin/bash
set -e

echo "==================================================="
echo "   Custom Linux Distro Builder (KDE Plasma)        "
echo "==================================================="

echo "[1/5] Installing required dependencies..."
sudo apt-get update
sudo apt-get install -y live-build debootstrap squashfs-tools xorriso curl git

BUILD_DIR=~/custom-os-build
echo "[2/5] Creating build directory at $BUILD_DIR..."
mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo "[3/5] Cleaning previous builds and configuring live-build..."
sudo lb clean || true

# Initialize live-build configuration for Debian 12 (Bookworm)
lb config \
    --architecture amd64 \
    --distribution bookworm \
    --archive-areas "main contrib non-free non-free-firmware" \
    --iso-application "Custom OS" \
    --iso-publisher "Custom Distro Project" \
    --iso-volume "CUSTOM_OS" \
    --bootappend-live "boot=live components locales=en_US.UTF-8 keyboard-layouts=us"

echo "[4/5] Setting up package lists for KDE Plasma..."
mkdir -p config/package-lists
cat <<EOF > config/package-lists/desktop.list.chroot
# Desktop Environment
kde-plasma-desktop
sddm

# Installer
calamares
calamares-settings-debian

# Core Utilities
sudo
network-manager
plasma-nm
nano
curl
wget
git
htop
EOF

echo "[5/5] Building the ISO... (This will take 15-30 minutes depending on internet speed)"
sudo lb build

echo "==================================================="
echo "Build complete! Copying ISO to Windows directory..."
echo "==================================================="

# The user's Windows path converted to WSL format
WIN_DEST="/mnt/c/Users/aky69/OneDrive/Documents/Antigravity Projects/Linux Distro"
mkdir -p "$WIN_DEST/output"

# live-build outputs the ISO in the current directory
if ls *.iso 1> /dev/null 2>&1; then
    cp *.iso "$WIN_DEST/output/custom-os-kde.iso"
    echo "Done! You can find your ISO at:"
    echo "C:\Users\aky69\OneDrive\Documents\Antigravity Projects\Linux Distro\output\custom-os-kde.iso"
else
    echo "Error: ISO file not found. The build might have failed."
    exit 1
fi
