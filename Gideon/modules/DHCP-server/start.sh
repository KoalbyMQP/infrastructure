#!/bin/bash

set -e

Root

# ==== CONFIG ====
STATIC_IP="192.168.99.1"
SUBNET_MASK="24"
NFS_ROOT="/srv/nfs/rpi-root"
TFTP_ROOT="/srv/tftp"
XZ_FILE="raspios_lite_latest.xz"
PRIMARY_IF_FILE="/etc/netboot-primary-if.conf"
MOUNT_ROOT_DIR="/mnt/rpi-root"
MOUNT_BOOT_DIR="/mnt/rpi-boot"
# ================

# --- Argument parsing ---
if [ $# -ne 1 ]; then
    echo "Usage: $0 <Network_Interface>"
    exit 1
fi

INTERFACE="$1"

# --- Detect and store primary interface ---
DEFAULT_ROUTE_IF=$(ip route | awk '/default/ {print $5}' | head -n 1)
if [ ! -f "$PRIMARY_IF_FILE" ]; then
    echo "$DEFAULT_ROUTE_IF" > "$PRIMARY_IF_FILE"
    echo "Saved primary interface as '$DEFAULT_ROUTE_IF'"
else
    DEFAULT_ROUTE_IF=$(cat "$PRIMARY_IF_FILE")
    echo "Using saved primary interface: $DEFAULT_ROUTE_IF"
fi


# --- Validate interface ---


# --- Configure network boot interface ---
echo "Configuring network boot interface $INTERFACE..."
ip addr flush dev "$INTERFACE"
ip link set "$INTERFACE" up
ip addr add "$STATIC_IP"/"$SUBNET_MASK" dev "$INTERFACE"

# --- Install required packages ---
echo "[1/6] Installing packages..."
apt update
apt install -y dnsmasq nfs-kernel-server unzip wget util-linux rsync xz-utils

# --- Create necessary directories ---
echo "[2/6] Creating directories..."
mkdir -p "$TFTP_ROOT" "$NFS_ROOT" "$MOUNT_ROOT_DIR" "$MOUNT_BOOT_DIR"

# --- Configure dnsmasq ---
echo "[3/6] Configuring dnsmasq..."
tee /etc/dnsmasq.d/pxepi.conf > /dev/null <<EOF
port=0
interface=$INTERFACE
bind-interfaces
dhcp-range=192.168.99.50,192.168.99.100,12h
enable-tftp
tftp-root=$TFTP_ROOT
dhcp-boot=bootcode.bin
log-queries
log-dhcp

dhcp-option=3,$STATIC_IP
dhcp-option=66,$STATIC_IP
EOF

# --- Configure NFS exports ---
echo "[4/6] Exporting NFS root..."
echo "$NFS_ROOT *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports
exportfs -ra

# --- Download Raspberry Pi OS Lite image ---
echo "[5/6] Downloading Raspberry Pi OS Lite image..."
cd /srv/nfs
if [ ! -f "$XZ_FILE" ]; then
    echo "⬇️ Downloading Raspberry Pi OS Lite..."
    wget -O "$XZ_FILE" https://downloads.raspberrypi.com/raspios_lite_armhf_latest
fi

# --- Extract .img from XZ if needed ---
echo "[6/6] Extracting .img from XZ..."
IMG_FILE="${XZ_FILE%.xz}.img"

if [ -z "$XZ_FILE" ]; then
    echo "XZ_FILE variable is empty."
    exit 1
fi
if [ ! -f "$XZ_FILE" ]; then
    echo "File '$XZ_FILE' not found. Cannot extract."
    exit 1
fi
if [ -f "$IMG_FILE" ]; then
    echo "$IMG_FILE already exists, skipping decompression."
else
    echo "Decompressing $XZ_FILE..."
    xz -dckf "$XZ_FILE" > "$IMG_FILE"
    if [ ! -f "$IMG_FILE" ]; then
        echo "Failed to extract .img from $XZ_FILE"
        exit 1
    fi
fi

# --- Mount partitions and copy files ---
echo "🔧 Mounting partitions and copying files..."
LOOPDEV=$(losetup -f --show -P "$IMG_FILE")
ROOT_PART="${LOOPDEV}p2"
BOOT_PART="${LOOPDEV}p1"

# Root filesystem
if [ ! -b "$ROOT_PART" ]; then
    echo "Root partition $ROOT_PART not found!"
    losetup -d "$LOOPDEV"
    exit 1
fi
mount "$ROOT_PART" "$MOUNT_ROOT_DIR"
rsync -aAX "$MOUNT_ROOT_DIR/" "$NFS_ROOT/"
umount "$MOUNT_ROOT_DIR"

# Boot files
if [ ! -b "$BOOT_PART" ]; then
    echo "Boot partition $BOOT_PART not found!"
    losetup -d "$LOOPDEV"
    exit 1
fi
mount "$BOOT_PART" "$MOUNT_BOOT_DIR"
echo "Copying boot partition files to $TFTP_ROOT..."
rsync -av "$MOUNT_BOOT_DIR/" "$TFTP_ROOT/"
umount "$MOUNT_BOOT_DIR"

# Detach loop device
losetup -d "$LOOPDEV"

# --- Create cmdline.txt for NFS boot ---
echo "Creating cmdline.txt in $TFTP_ROOT..."
NFS_CMDLINE="dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=$STATIC_IP:$NFS_ROOT,vers=3 rw ip=dhcp rootwait     "
echo "$NFS_CMDLINE" > "$TFTP_ROOT/cmdline.txt"

echo "cmdline.txt created. Place any additional boot files in $TFTP_ROOT."

# --- Restart services ---
echo "Restarting services..."
systemctl restart dnsmasq
systemctl restart nfs-server

# --- Verify interface IP ---
echo "🧪 Verifying IP assignment on $INTERFACE..."
if ! ip -4 addr show "$INTERFACE" | grep -q "$STATIC_IP"; then
    echo "Failed to assign static IP to $INTERFACE."
    exit 1
fi

echo "$INTERFACE has IP $STATIC_IP"
echo "Netboot environment is ready on interface: $INTERFACE"
echo "Done"







# Ensure the script is run as root
Root(){
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Please run with sudo:" >&2
  echo "   sudo $0 $*" >&2
  exit 1
fi
}


