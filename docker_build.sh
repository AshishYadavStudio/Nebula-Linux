#!/bin/bash
set -e

echo "==================================================="
echo "   Nebula Linux Builder (Polish & Fixes Edition)   "
echo "==================================================="

echo "[1/5] Cleaning previous builds..."
# We MUST use --purge to delete the old Debian 12 cache. Mixing old Bookworm packages with new Trixie packages will cause a crash.
lb clean --purge || true

echo "[2/5] Configuring live-build for Nebula Linux..."
lb config \
    --architecture amd64 \
    --distribution trixie \
    --archive-areas "main contrib non-free non-free-firmware" \
    --iso-application "Nebula Linux" \
    --iso-publisher "Nebula OS Team" \
    --iso-volume "NEBULA_OS" \
    --bootappend-live "boot=live components locales=en_US.UTF-8 keyboard-layouts=us splash quiet" \
    --mirror-bootstrap "http://ftp.us.debian.org/debian/" \
    --mirror-chroot "http://ftp.us.debian.org/debian/" \
    --mirror-binary "http://ftp.us.debian.org/debian/" \
    --security false

echo "[2/5] Setting up package lists for Nebula features..."
mkdir -p config/package-lists
cat <<EOF > config/package-lists/desktop.list.chroot
# Desktop Environment (Wayland Default in Plasma 6)
kde-plasma-desktop
sddm

# App Store & Software
plasma-discover
plasma-discover-backend-flatpak
flatpak
vlc
kde-spectacle
ark
firefox-esr
libreoffice

# Theming & Icons
arc-theme
papirus-icon-theme
breeze-icon-theme
plasma-workspace-wallpapers

# Core Utilities & Drivers
firmware-linux
sudo
network-manager
plasma-nm
wpasupplicant
iw
wireless-tools
nano
curl
wget
git
htop
timeshift
python3-pyqt5
python3-tk

# Installer
calamares
calamares-settings-debian
EOF

echo "[3/5] Injecting Nebula Features and Hooks..."

# 1. Flatpak/Flathub Hook
mkdir -p config/hooks/live
cat <<'EOF' > config/hooks/live/10-flathub.hook.chroot
#!/bin/sh
set -e
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
EOF
chmod +x config/hooks/live/10-flathub.hook.chroot

# 2. Fastfetch Install Hook
cat <<'EOF' > config/hooks/live/11-fastfetch.hook.chroot
#!/bin/sh
set -e
wget -q https://github.com/fastfetch-cli/fastfetch/releases/download/2.15.0/fastfetch-linux-amd64.deb -O /tmp/fastfetch.deb
dpkg -i /tmp/fastfetch.deb || apt-get install -f -y
rm -f /tmp/fastfetch.deb
EOF
chmod +x config/hooks/live/11-fastfetch.hook.chroot

# 3. Welcome App Integration
mkdir -p config/includes.chroot/usr/local/bin
cp /build/nebula_welcome.py config/includes.chroot/usr/local/bin/nebula-welcome
chmod +x config/includes.chroot/usr/local/bin/nebula-welcome

mkdir -p config/includes.chroot/etc/skel/.config/autostart
cat <<EOF > config/includes.chroot/etc/skel/.config/autostart/nebula-welcome.desktop
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/nebula-welcome
Name=Nebula Welcome
Comment=Welcome to Nebula Linux
X-GNOME-Autostart-enabled=true
EOF

# 3.5 Bug Reporter App Integration
cp /build/nebula_bug_reporter.py config/includes.chroot/usr/local/bin/nebula-bug-reporter
chmod +x config/includes.chroot/usr/local/bin/nebula-bug-reporter

mkdir -p config/includes.chroot/usr/share/applications
cat <<EOF > config/includes.chroot/usr/share/applications/nebula-bug-reporter.desktop
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/nebula-bug-reporter
Icon=tools-report-bug
Name=Report a Bug
Comment=Report an issue to the Nebula Linux team
Categories=System;Utility;
EOF

# 4. SDDM Wayland Config
mkdir -p config/includes.chroot/etc/sddm.conf.d
cat <<EOF > config/includes.chroot/etc/sddm.conf.d/default.conf
[General]
DisplayServer=wayland
EOF

# 5. Bootloader Splash Formatting
mkdir -p config/bootloaders/isolinux
mkdir -p config/bootloaders/grub

# Format wallpaper.png specifically for ISOLINUX (640x480, 8-bit palette)
convert /build/assets/wallpaper.png -resize 640x480\! -colors 256 config/bootloaders/isolinux/splash.png
cp /build/assets/wallpaper.png config/bootloaders/grub/splash.png

# 6. Desktop Wallpaper Placement
mkdir -p config/includes.chroot/usr/share/wallpapers/Nebula/contents/images
cp /build/assets/wallpaper.png config/includes.chroot/usr/share/wallpapers/Nebula/contents/images/1920x1080.png

# 7. Fast Animations & Minimalist Arc Theme
mkdir -p config/includes.chroot/etc/skel/.config
cat <<EOF > config/includes.chroot/etc/skel/.config/kdeglobals
[General]
ColorScheme=ArcDark
Name=Arc Dark

[Icons]
Theme=Papirus-Dark

[KDE]
AnimationDurationFactor=0.5
EOF

# 8. Calamares Installer Branding
mkdir -p config/includes.chroot/etc/calamares/branding/nebula
cp /build/assets/splash.png config/includes.chroot/etc/calamares/branding/nebula/logo.png
cat <<EOF > config/includes.chroot/etc/calamares/branding/nebula/branding.desc
---
componentName:  nebula
windowExpanding: normal
windowSize: 800px,520px
windowPlacement: center

strings:
    productName:         Nebula Linux
    shortProductName:    Nebula
    version:             1.0
    shortVersion:        1.0
    versionedName:       Nebula Linux 1.0
    shortVersionedName:  Nebula 1.0
    bootloaderEntryName: Nebula

images:
    productLogo:         "logo.png"
    productIcon:         "logo.png"
    productWelcome:      "logo.png"

slideshow:               "show.qml"
EOF

cat <<'EOF' > config/includes.chroot/etc/calamares/branding/nebula/show.qml
import QtQuick

Rectangle {
    color: "#0b0c10"
    Text {
        anchors.centerIn: parent
        text: "Installing Nebula Linux..."
        color: "#00e5ff"
        font.pixelSize: 24
    }
}
EOF



cat <<'EOF' > config/hooks/live/98-calamares.hook.chroot
#!/bin/sh
set -e
# Ensure settings.conf uses our 'nebula' branding instead of 'debian'
if [ -f /etc/calamares/settings.conf ]; then
    sed -i 's/branding: debian/branding: nebula/g' /etc/calamares/settings.conf
fi

# Fix Wayland Root GUI bug for the desktop installer shortcut
for desk in /usr/share/applications/install-debian.desktop /usr/share/applications/calamares.desktop; do
    if [ -f "$desk" ]; then
        sed -i 's/^Exec=.*/Exec=sh -c "xhost +si:localuser:root \&\& pkexec calamares"/' "$desk"
    fi
done
EOF
chmod +x config/hooks/live/98-calamares.hook.chroot

# 9. System About Page Branding
cat <<'EOF' > config/hooks/live/99-os-release.hook.chroot
#!/bin/sh
set -e
cat <<OSREL > /etc/os-release
PRETTY_NAME="Nebula Linux 1.0"
NAME="Nebula Linux"
VERSION="1.0"
ID=nebula
ID_LIKE=debian
HOME_URL="https://nebula-linux-os.github.io/Nebula-Linux/"
SUPPORT_URL="https://github.com/nebula-linux-os/Nebula-Linux/issues"
BUG_REPORT_URL="https://github.com/nebula-linux-os/Nebula-Linux/issues"
OSREL
EOF
chmod +x config/hooks/live/99-os-release.hook.chroot

echo "[4/5] Building the ISO..."
lb build

echo "==================================================="
echo "Build complete! Copying ISO to output directory..."
echo "==================================================="
mkdir -p /output
if ls *.iso 1> /dev/null 2>&1; then
    cp *.iso /output/nebula-linux-kde.iso
    echo "Done! ISO successfully copied to your output folder."
else
    echo "Error: ISO file not found. The build might have failed."
    exit 1
fi
