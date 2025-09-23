#!/bin/bash
set -e

# ========================
# CONFIGURATION VARIABLES
# ========================
STATIC_IP="192.168.99.1"
SUBNET_MASK="24"
NFS_ROOT="/srv/nfs/rpi-root"
TFTP_ROOT="/srv/tftp"
XZ_FILE="raspios_lite_latest.xz"
PRIMARY_IF_FILE="/etc/netboot-primary-if.conf"
MOUNT_ROOT_DIR="/mnt/rpi-root"
MOUNT_BOOT_DIR="/mnt/rpi-boot"
PI_firmware="$(pwd)/pi5-firmware"
FIRMWARE_URL="https://github.com/raspberrypi/rpi-eeprom/tree/master/firmware-2712/default/pieeprom-2025-05-08.bin"
FIRMWARE_FILE="pieeprom.bin"
SIG_FILE="pieeprom.sig"
DEBIAN_MIRROR="http://deb.debian.org/debian"

# Update as first RPi when adding support for more
PI_Number="78def64a"

# ========================
# UTILITY FUNCTIONS
# ========================

# Ensure the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ This script must be run as root. Please run with sudo:" >&2
        echo "   sudo $0 $*" >&2
        exit 1
    fi
}

# Parse arguments: requires interface + runmode
parse_args() {
    if [ $# -lt 2 ]; then
        echo "❌ Usage: $0 <Network_Interface> <Run_Mode>"
        exit 1
    fi
    INTERFACE="$1"
    RUNMODE="$2"
}

# Detect and save or reuse the primary interface
detect_primary_interface() {
    DEFAULT_ROUTE_IF=$(ip route | awk '/default/ {print $5}' | head -n 1)
    if [ ! -f "$PRIMARY_IF_FILE" ]; then
        echo "$DEFAULT_ROUTE_IF" > "$PRIMARY_IF_FILE"
        echo "📌 Saved primary interface as '$DEFAULT_ROUTE_IF'"
    else
        DEFAULT_ROUTE_IF=$(cat "$PRIMARY_IF_FILE")
        echo "📎 Using saved primary interface: $DEFAULT_ROUTE_IF"
    fi
}

# Validate that the chosen interface exists and isn’t the primary
validate_interface() {
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        echo "❌ Interface '$INTERFACE' not found."
        exit 1
    fi
    if [ "$INTERFACE" = "$DEFAULT_ROUTE_IF" ]; then
        echo "❌ Cannot use primary interface '$DEFAULT_ROUTE_IF' for network boot!"
        exit 1
    fi
}

# Configure interface with static IP for netboot
configure_interface() {
    echo "⚙️ Configuring network boot interface $INTERFACE..."
    ip addr flush dev "$INTERFACE"
    ip link set "$INTERFACE" up
    ip addr add "$STATIC_IP"/"$SUBNET_MASK" dev "$INTERFACE"
}

# Install required packages
install_packages() {
    echo "[1/7] Installing packages..."
    apt update
    apt install -y dnsmasq nfs-kernel-server unzip wget util-linux rsync xz-utils git \
        build-essential libssl-dev debootstrap qemu-user-static binfmt-support
}

# Create necessary directories
create_directories() {
    echo "[2/7] Creating directories..."
    mkdir -p "$TFTP_ROOT/$PI_Number" \
             "$NFS_ROOT/$PI_Number" \
             "$MOUNT_ROOT_DIR" \
             "$MOUNT_BOOT_DIR" \
             "$PI_firmware/rpi-eeprom"
}

# Configure dnsmasq DHCP/TFTP
configure_dnsmasq() {
    echo "[3/7] Configuring dnsmasq..."
    tee /etc/dnsmasq.d/pxepi.conf > /dev/null <<EOF
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
}

# Open firewall ports for DHCP/TFTP/NFS
configure_firewall() {
    echo "Configuring firewall rules..."
    ufw allow 67/udp comment 'Allow DHCP requests'
    ufw allow 69/udp comment 'Allow TFTP requests'
    ufw allow 2049/tcp comment 'Allow NFS'
    ufw allow 111/tcp comment 'Allow RPCbind (NFS dependency)'
    ufw allow 111/udp comment 'Allow RPCbind (NFS dependency)'
    ufw status
}

# Download Raspberry Pi OS Lite image if missing
download_rpi_image() {
    echo "[5/7] Downloading Raspberry Pi OS Lite image..."
    cd /srv/nfs
    if [ ! -f "$XZ_FILE" ]; then
        echo "⬇️ Downloading Raspberry Pi OS Lite..."
        wget -O "$XZ_FILE" https://downloads.raspberrypi.com/raspios_lite_armhf_latest
    fi
}

# Extract partitions from .img and copy into NFS/TFTP
extract_img_partitions() {
    echo "[6/7] Extracting image partitions..."
    IMG_FILE="${XZ_FILE%.xz}.img"
    if [ ! -f "$IMG_FILE" ]; then
        echo "📦 Decompressing $XZ_FILE..."
        xz -dckf "$XZ_FILE" > "$IMG_FILE"
    fi

    local loopdev
    loopdev="$(losetup -f --show -P $IMG_FILE)"

    # Mount and copy root partition
    mount "${loopdev}p2" "$MOUNT_ROOT_DIR"
    rsync -aAX "$MOUNT_ROOT_DIR/" "$NFS_ROOT/$PI_Number"
    umount "$MOUNT_ROOT_DIR"

    # Mount and copy boot partition
    mount "${loopdev}p1" "$MOUNT_BOOT_DIR"
    rsync -av "$MOUNT_BOOT_DIR/" "$TFTP_ROOT/$PI_Number"
    umount "$MOUNT_BOOT_DIR"

    losetup -d "$loopdev"
}

# Export root via NFS
configure_nfs_exports() {
    echo "[6.5/7] Exporting NFS root..."
    tee "$NFS_ROOT/$PI_Number/etc/network/interfaces" > /dev/null <<EOF
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
EOF

    cp /home/lab/NetBootPi/stash/$PI_Number/hostname "$NFS_ROOT/$PI_Number/etc/hostname"
    cp /home/lab/NetBootPi/stash/$PI_Number/hosts "$NFS_ROOT/$PI_Number/etc/hosts"

    cp /usr/bin/qemu-aarch64-static "$NFS_ROOT/$PI_Number/usr/bin/"
    chroot "$NFS_ROOT/$PI_Number" passwd || echo "Skipping root password set"
    rm "$NFS_ROOT/$PI_Number/usr/bin/qemu-aarch64-static"

    echo "$NFS_ROOT/$PI_Number *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports
    systemctl enable --now nfs-server
    exportfs -ra
}

# Download firmware and generate .sig
generate_firmware_files() {
    echo "[7/7] Generating firmware files..."
    cd "$PI_firmware"
    wget -O "$FIRMWARE_FILE" "$FIRMWARE_URL"

    if [ ! -d "rpi-eeprom" ]; then
        git clone https://github.com/raspberrypi/rpi-eeprom.git
    else
        (cd rpi-eeprom && git pull)
    fi

    make -C rpi-eeprom rpi-eeprom-digest
    rpi-eeprom/rpi-eeprom-digest -i "$FIRMWARE_FILE" -o "$SIG_FILE"

    cp "$FIRMWARE_FILE" "$SIG_FILE" "$TFTP_ROOT/$PI_Number"
}

# Write cmdline.txt for NFS boot
create_cmdline_txt() {
    echo "📄 Creating cmdline.txt..."
    local CMD="console=serial0,115200 console=tty1 root=/dev/nfs rootfstype=nfs \
nfsroot=$STATIC_IP:$NFS_ROOT/$PI_Number,vers=3 rw ip=dhcp rootwait splash init=/lib/systemd/systemd"
    echo "$CMD" > "$TFTP_ROOT/$PI_Number/cmdline.txt"
}

# Restart services and verify
finalize_setup() {
    echo "🔁 Restarting services..."
    systemctl restart dnsmasq
    systemctl restart nfs-server

    echo "🧪 Verifying IP assignment on $INTERFACE..."
    if ! ip -4 addr show "$INTERFACE" | grep -q "$STATIC_IP"; then
        echo "❌ Failed to assign static IP to $INTERFACE."
        exit 1
    fi
    echo "✅ $INTERFACE has IP $STATIC_IP"
    echo "🎉 Netboot environment is ready!"
}

# ========================
# MAIN ENTRY POINT
# ========================
main() {
    check_root
    parse_args "$@"

    if [ "$RUNMODE" == "--fw-only" ]; then
        generate_firmware_files
        exit $?
    fi

    detect_primary_interface
    validate_interface
    configure_interface
    install_packages
    create_directories
    configure_dnsmasq
    configure_firewall
    download_rpi_image
    extract_img_partitions
    configure_nfs_exports
    generate_firmware_files
    create_cmdline_txt
    finalize_setup
}

main "$@"