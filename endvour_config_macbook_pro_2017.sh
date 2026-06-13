#!/bin/bash

# Stop script if a command fails
set -e

echo "================================================================="
echo "   👑 MACBOOK PRO 2017 CONFIGURATION SCRIPT (FINAL GRUB) 👑   "
echo "================================================================="

if [ "$EUID" -ne 0 ]; then
  echo "👉 This script requires administrative privileges. Please enter your password."
fi

# -----------------------------------------------------------------
# 1. REPOSITORY UPDATE AND DEPENDENCIES
# -----------------------------------------------------------------
echo -e "\n🔹 [1/5] Checking and installing base dependencies..."
sudo pacman -S --needed --noconfirm git base-devel dkms linux-headers

# -----------------------------------------------------------------
# 2. AUDIO CONFIGURATION (CIRRUS LOGIC CS8409 PATCH)
# -----------------------------------------------------------------
echo -e "\n🔹 [2/5] Configuring Cirrus Logic Audio driver..."
MODULE_NAME="snd-hda-macbookpro"
MODULE_VERSION="0.1"
SRC_DIR="/usr/src/${MODULE_NAME}-${MODULE_VERSION}"

if dkms status | grep -q "${MODULE_NAME}"; then
    echo "   -> Removing old DKMS instance..."
    sudo dkms remove -m "${MODULE_NAME}" -v "${MODULE_VERSION}" --all || true
fi

if [ -d "${SRC_DIR}" ]; then sudo rm -rf "${SRC_DIR}"; fi

echo "   -> Downloading sources and applying Patch for Kernel 7.x+..."
sudo git clone https://github.com/davidjo/snd_hda_macbookpro.git "${SRC_DIR}"

DKMS_CONF="${SRC_DIR}/dkms.conf"
if [ -f "$DKMS_CONF" ]; then
    sudo sed -i '/BUILT_MODULE_LOCATION\[0\]/d' "$DKMS_CONF"
    echo 'BUILT_MODULE_LOCATION[0]="build/hda/codecs/cirrus"' | sudo tee -a "$DKMS_CONF" > /dev/null
else
    echo "   ❌ Error: dkms.conf not found!"; exit 1
fi

sudo dkms add -m "${MODULE_NAME}" -v "${MODULE_VERSION}"
sudo dkms install -m "${MODULE_NAME}" -v "${MODULE_VERSION}"
echo "   ✅ Audio DKMS ready!"

# -----------------------------------------------------------------
# 3. CONNECTIVITY & FANS (BLUETOOTH + OPTIMIZED MBPFAN)
# -----------------------------------------------------------------
echo -e "\n🔹 [3/5] Activating hardware services (Bluetooth and Fans)..."

# Bluetooth
sudo systemctl enable --now bluetooth

# Fan Control (mbpfan from AUR via yay)
if ! command -v mbpfan &> /dev/null; then
    echo "   -> Installing mbpfan from AUR..."
    yay -S --noconfirm mbpfan
fi

# Writing configuration with integrated original comments
echo "   -> Writing custom configuration to /etc/mbpfan.conf..."
sudo tee /etc/mbpfan.conf > /dev/null <<EOF
[general]
min_fan_speed = 1300    # Default Apple minimum
max_fan_speed = 7200    # Maximum speed for MacBookPro14,1 single fan
low_temp = 55           # Fan starts ramping up
high_temp = 62          # Fan hits maximum speed before heavy throttling
max_local_temp = 86     # Safety ceiling
polling_interval = 2    # Checked every 2 seconds
EOF

sudo systemctl enable --now mbpfan
sudo systemctl restart mbpfan
echo "   ✅ Bluetooth and Fans active with a balanced thermal profile!"

# -----------------------------------------------------------------
# 4. ADVANCED DSP AUDIO (EASYEFFECTS)
# -----------------------------------------------------------------
echo -e "\n🔹 [4/5] Installing EasyEffects and Laptop Presets..."
sudo pacman -S --needed --noconfirm easyeffects lsp-plugins calf

if [ ! -d "$HOME/.config/easyeffects/output" ]; then
    echo "   -> Downloading acoustic presets (Advanced Audio Gain)..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/JackHack96/EasyEffects-Presets/master/install.sh)" -- --silent
fi
echo "   ✅ Audio Suite configured!"

# -----------------------------------------------------------------
# 5. AUTOMATIC SPLASH SCREEN (PLYMOUTH ON GRUB)
# -----------------------------------------------------------------
echo -e "\n🔹 [5/5] Installing and configuring Splash Screen (GRUB)..."

# Installing Plymouth
sudo pacman -S --needed --noconfirm plymouth

# Set 'spinner' graphical theme
echo "   -> Configuring Plymouth graphical theme..."
sudo plymouth-set-default-theme spinner

GRUB_CONF="/etc/default/grub"
if [ -f "$GRUB_CONF" ]; then
    echo "    -> Aligning GRUB parameters..."

    sudo sed -i 's/ pcie_ports=compat//g' "$GRUB_CONF"
    sudo sed -i 's/pcie_ports=compat //g' "$GRUB_CONF"

    if ! grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=.*quiet" "$GRUB_CONF"; then
        sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=['\"])/\1quiet /" "$GRUB_CONF"
    fi

    if ! grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=.*splash" "$GRUB_CONF"; then
        sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=['\"])/\1splash /" "$GRUB_CONF"
    fi

    echo "    -> Regenerating GRUB menu..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "    ❌ Critical Error: /etc/default/grub not found!"
    exit 1
fi

# Regenerating Initramfs (Dracut or Mkinitcpio)
echo "   -> Including Plymouth in the boot image..."
if command -v dracut &> /dev/null; then
    echo "   -> Detected Dracut: Regenerating initramfs..."
    sudo dracut-rebuild || sudo dracut --force
elif command -v mkinitcpio &> /dev/null; then
    echo "   -> Detected Mkinitcpio: Checking HOOKS..."
    if [ -f "/etc/mkinitcpio.conf" ] && ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sudo sed -i 's/HOOKS=(/HOOKS=(plymouth /I' /etc/mkinitcpio.conf
    fi
    sudo mkinitcpio -P
fi

echo "   ✅ Bootloader successfully configured!"

# -----------------------------------------------------------------
# END
# -----------------------------------------------------------------
echo -e "\n================================================================="
echo " 🎉 MACBOOK PRO FULLY OPTIMIZED!"
echo "================================================================="
echo " 🛠️  STATUS & OPERATIONS SUMMARY:"
echo " 1. AUDIO: Automated DKMS drivers and Cirrus Logic patch."
echo " 2. FANS: Custom monitoring (55°C-62°C, checked every 2s)."
echo " 3. GRAPHICS: Active 'spinner' splash screen on GRUB at boot."
echo " 4. USB PORTS: Resolved via hardware (remember to use the USB-C hub)."
echo " 5. DSP AUDIO: Installed EasyEffects presets (Advanced Audio Gain)."
echo " "
echo " ⚠️  IMPORTANT REMINDER:"
echo " To load the preset (Advanced Audio Gain) at every boot,"
echo " open the EasyEffects interface, go to its global settings"
echo " (Preferences) and enable the native option to launch with the system"
echo " ('Launch at login') in the background."
echo " Select Advanced Audio Gain from the EasyEffects profiles."
echo "================================================================="
