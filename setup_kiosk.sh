#!/bin/bash
set -e

### CONFIGURATION ###
KIOSK_USER="kiosk"
RUSTDESK_PASS="MySecretPassword"
REPO_BASE="https://raw.githubusercontent.com/Grydot/dwkiosk/main"
DW_DEB="https://updates.digital-watchdog.com/digitalwatchdog/40736/linux/dwspectrum-client-6.0.3.40736-linux_x64.deb"
RUSTDESK_DEB="https://github.com/rustdesk/rustdesk/releases/download/1.4.1/rustdesk-1.4.1-x86_64.deb"

echo "Starting Kiosk Setup..."

### 1. Create kiosk user (no password, autologin) ###
if ! id "$KIOSK_USER" &>/dev/null; then
    sudo adduser --disabled-password --gecos "" "$KIOSK_USER"
    sudo usermod -aG sudo "$KIOSK_USER"
fi

### 2. Setup autologin override (dynamic user) ###
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF
sudo systemctl daemon-reexec

### 3. Install dependencies ###
sudo apt-get update
sudo apt-get install -y i3 xorg x11-xserver-utils xterm feh curl wget \
    libxcomposite1 libxrandr2 libxkbcommon-x11-0

### 4. Install DW Spectrum ###
wget -O /tmp/dwspectrum.deb "$DW_DEB"
sudo dpkg -i /tmp/dwspectrum.deb || sudo apt-get install -f -y

# Find newest DW Spectrum client folder
LATEST_DIR=$(ls -dt /opt/digitalwatchdog/client/*/ | head -1)

# Point "latest" symlink to it
sudo ln -sfn "${LATEST_DIR}bin/applauncher" /opt/digitalwatchdog/client/latest

# Global launcher in /bin
sudo ln -sfn /opt/digitalwatchdog/client/latest /bin/dwspectrum

### 5. Install RustDesk ###
wget -O /tmp/rustdesk.deb "$RUSTDESK_DEB"
sudo dpkg -i /tmp/rustdesk.deb || sudo apt-get install -f -y
sudo systemctl enable rustdesk

### 6. Download i3 config ###
sudo mkdir -p /etc/i3
sudo wget -O /etc/i3/config "$REPO_BASE/i3/config"

### 7. Download .bashrc and .xinitrc from repo ###
wget -O /home/$KIOSK_USER/.bashrc "$REPO_BASE/.bashrc"
wget -O /home/$KIOSK_USER/.xinitrc "$REPO_BASE/.xinitrc"

### 7b. Ensure autostart of X in .bashrc ###
BASHRC="/home/$KIOSK_USER/.bashrc"
if ! grep -q "exec startx" "$BASHRC"; then
cat >> "$BASHRC" <<'EOF'

# Auto-start X on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF
fi

### 7c. Ensure .xinitrc launches i3 ###
XINITRC="/home/$KIOSK_USER/.xinitrc"
if ! grep -q "exec i3" "$XINITRC" 2>/dev/null; then
    echo 'exec i3' >> "$XINITRC"
fi

chmod +x "$XINITRC"
chown $KIOSK_USER:$KIOSK_USER "$BASHRC" "$XINITRC"

### 8. Deploy background.png from repo ###
sudo mkdir -p /opt/dwkiosk
sudo wget -O /opt/dwkiosk/background.png "$REPO_BASE/background.png"

### 9. Show RustDesk ID ###
echo " "
echo "Fetching RustDesk ID..."
sleep 2
if command -v rustdesk &>/dev/null; then
    RUSTDESK_ID=$(rustdesk --get-id || echo "(RustDesk not running yet)")
else
    RUSTDESK_ID="(RustDesk not installed)"
fi

### 10. Final message ###
echo "Setup complete!"
echo "RustDesk ID: $RUSTDESK_ID"
echo "RustDesk Password: $RUSTDESK_PASS"
echo "Reboot to start kiosk mode."
