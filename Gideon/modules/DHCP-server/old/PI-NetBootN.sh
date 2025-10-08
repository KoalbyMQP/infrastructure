#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Please run with sudo:" >&2
  echo "   sudo $0 $*" >&2
  exit 1
fi

# ==== CONFIG ====
STATIC_IP="192.168.99.1"
SUBNET_MASK="24"
NFS_ROOT="/srv/nfs/rpi-root"
TFTP_ROOT="/srv/tftp"
ZIP_FILE="raspios_lite_latest.zip"
PRIMARY_IF_FILE="/etc/netboot-primary-if.conf"
# ================

# --- Argument parsing ---
if [ $# -ne 1 ]; then
    echo "❌ Usage: $0 <Subnet_INTERFACE>"
    exit 1
fi

INTERFACE="$1"

# --- Detect and store primary interface ---
DEFAULT_ROUTE_IF=$(ip route | awk '/default/ {print $5}' | head -n 1)
if [ ! -f "$PRIMARY_IF_FILE" ]; then
    echo "$DEFAULT_ROUTE_IF" > "$PRIMARY_IF_FILE"
    echo "📌 Saved primary interface as '$DEFAULT_ROUTE_IF'"
else
    DEFAULT_ROUTE_IF=$(cat "$PRIMARY_IF_FILE")
    echo "📎 Using saved primary interface: $DEFAULT_ROUTE_IF"
fi

# --- Validate interface ---
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
    echo "❌ Interface '$INTERFACE' not found."
    exit 1
fi
if [ "$INTERFACE" = "$DEFAULT_ROUTE_IF" ]; then
    echo "❌ Cannot use primary interface '$DEFAULT_ROUTE_IF' for Network boot!"
    exit 1
fi

# --- Save original default gateway and interface for internet access ---
ORIG_DEFAULT_IF=$(ip route | awk '/default/ {print $5; exit}')
ORIG_DEFAULT_GW=$(ip route | awk '/default/ {print $3; exit}')
echo "🌐 Original default route: via $ORIG_DEFAULT_GW dev $ORIG_DEFAULT_IF"

# --- Configure network boot interface ---
echo "⚙️ Configuring Network boot interface $INTERFACE..."
sudo ip addr flush dev "$INTERFACE"
sudo ip link set "$INTERFACE" up
sudo ip addr add "$STATIC_IP"/"$SUBNET_MASK" dev "$INTERFACE"

# --- Restore original default route to ensure internet access ---
echo "🔄 Restoring default route via $ORIG_DEFAULT_GW dev $ORIG_DEFAULT_IF"
sudo ip route add default via "$ORIG_DEFAULT_GW" dev "$ORIG_DEFAULT_IF" metric 100 || true

# --- Verify default route ---
ip route show default

# --- Install packages ---
echo "[1/6] Installing packages..."
sudo apt update
sudo apt install -y dnsmasq nfs-kernel-server unzip wget util-linux rsync xz-utils

# --- Create directories ---
echo "[2/6] Creating directories..."
sudo mkdir -p "$TFTP_ROOT"
sudo mkdir -p "$NFS_ROOT"
sudo mkdir -p /mnt/rpi-root

# --- Configure dnsmasq ---
echo "[3/6] Configuring dnsmasq..."
sudo tee /etc/dnsmasq.d/pxepi.conf > /dev/null <<EOF
interface=$INTERFACE
bind-interfaces
dhcp-range=192.168.99.50,192.168.99.100,12h
enable-tftp
tftp-root=$TFTP_ROOT
dhcp-boot=bootcode.bin,,$STATIC_IP
log-queries
log-dhcp
EOF

# --- Configure NFS ---
echo "[4/6] Exporting NFS root..."
echo "$NFS_ROOT *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports > /dev/null
sudo exportfs -ra

# --- Download Raspberry Pi OS image ---
echo "[5/6] Downloading Raspberry Pi OS Lite image..."
cd /srv/nfs

# Download only if not already present
if [ -f "$ZIP_FILE" ]; then
rm "$ZIP_FILE"
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "⬇️ Downloading Raspberry Pi OS Lite image..."
    wget -4 -O "$ZIP_FILE" https://downloads.raspberrypi.com/raspios_lite_armhf_latest
fi

# --- Extract .img from ZIP if needed ---
IMG_FILE=$(unzip -Z1 "$ZIP_FILE" 2>/dev/null | grep '\.img$' || true)

if [ -z "$IMG_FILE" ]; then
    echo "❌ No .img file found inside ZIP archive. Please check the ZIP file."
    exit 1
fi

if [ ! -f "$IMG_FILE" ]; then
    echo "[6/6] Extracting .img from ZIP..."
    unzip -o "$ZIP_FILE"
else
    echo "✅ $IMG_FILE already extracted, skipping."
fi

# --- Setup loop device and mount root partition ---
IMG_FILE=$(find . -maxdepth 1 -name "*.img" | head -n 1)

if [ -z "$IMG_FILE" ]; then
    echo "❌ No .img file found after decompression."
    exit 1
fi

LOOPDEV=$(sudo losetup -f --show -P "$IMG_FILE")
ROOT_PART="${LOOPDEV}p2"
sudo mount "$ROOT_PART" /mnt/rpi-root
sudo rsync -aAX /mnt/rpi-root/ "$NFS_ROOT/"
sudo umount /mnt/rpi-root
sudo losetup -d "$LOOPDEV"

# --- Write TFTP boot files ---
echo "📄 Creating boot files in $TFTP_ROOT..."

NFS_CMDLINE="console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=$STATIC_IP:$NFS_ROOT,vers=3 rw ip=dhcp rootwait elevator=deadline"
echo "$NFS_CMDLINE" | sudo tee "$TFTP_ROOT/cmdline.txt"

echo "✅ cmdline.txt created for NFS boot."
echo "⚠️ Place required Raspberry Pi boot files (bootcode.bin, etc.) in $TFTP_ROOT"

# --- Restart services ---
echo "🔁 Restarting services..."
sudo systemctl restart dnsmasq
sudo systemctl restart nfs-server

echo "🧪 Verifying IP assignment on $INTERFACE..."
if ! ip -4 addr show "$INTERFACE" | grep -q "$STATIC_IP"; then
    echo "❌ Failed to assign static IP to $INTERFACE."
    exit 1
else
    echo "✅ $INTERFACE has IP $STATIC_IP"
fi

echo "🎉 Netboot environment ready on interface: $INTERFACE"

