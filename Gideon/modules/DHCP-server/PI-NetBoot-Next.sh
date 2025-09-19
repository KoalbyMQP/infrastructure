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
# ================

# --- Argument parsing ---
if [ $# -lt 2 ]; then
    echo "❌ Usage: $0 <Network_Interface> <Run_Mode>"
    exit 1
fi

INTERFACE="$1"
RUNMODE="$2"

# [ 6 / 7 ] helper
netboot_extract_img_root_partition () {
	local loopdev="$1"
	ROOT_PART="${loopdev}p2"
	# Root filesystem
	if [ ! -b "$ROOT_PART" ]; then
	    echo " Root partition $ROOT_PART not found!"
	    losetup -d "$loopdev"
	    exit 1
	fi
	mount "$ROOT_PART" "$MOUNT_ROOT_DIR"
	rsync -aAX "$MOUNT_ROOT_DIR/" "$NFS_ROOT/$PI_Number"
	umount "$MOUNT_ROOT_DIR"

}
# [6 / 7] helper
netboot_extract_img_boot_partition () {
	local loopdev="$1"
	BOOT_PART="${loopdev}p1"
	# Boot files
	if [ ! -b "$BOOT_PART" ]; then
	    echo " Boot partition $BOOT_PART not found!"
	    losetup -d "$loopdev"
	    exit 1
	fi
	mount "$BOOT_PART" "$MOUNT_BOOT_DIR"
	echo " Copying boot partition files to $TFTP_ROOT/$PI_Number..."
	rsync -av "$MOUNT_BOOT_DIR/" "$TFTP_ROOT/$PI_Number"
	umount "$MOUNT_BOOT_DIR"

}
# [6 / 7] 
netboot_extract_img_partitions () {
	# --- Mount partitions and copy files ---
	echo "🔧 Mounting partitions and copying files..."
	local loopdev="$(losetup -f --show -P $IMG_FILE)"
	netboot_extract_img_root_partition "$loopdev"
	netboot_extract_img_boot_partition "$loopdev"
	
	# Detach loop device
	losetup -d "$loopdev"
}

# [7 / 7]
netboot_fw_eprom_bin_and_sig () {
	# --- Makeing eprom .bin and .sig  ---

	echo "[7/7] Makeing eprom .bin and .sig"
	cd "$PI_firmware"

	echo "Downloading firmware from: $FIRMWARE_URL"
	wget -O "$FIRMWARE_FILE" "$FIRMWARE_URL"

	echo "Downloading rpi-eeprom Generator"

	if [ -d "rpi-eeprom" ]; then
	  cd rpi-eeprom
	  git pull
	  cd ..
	else
	  git clone https://github.com/raspberrypi/rpi-eeprom.git
	fi
	cd rpi-eeprom

	make rpi-eeprom-digest


	echo "Generating .sig file..."
	"$PI_firmware"/rpi-eeprom/rpi-eeprom-digest -i "$PI_firmware"/"$FIRMWARE_FILE" -o "$PI_firmware"/"$SIG_FILE"



	# All subfolders... not needed for now
	#echo "Copying $FIRMWARE_FILE and $SIG_FILE to all folders inside $TFTP_ROOT..."
	#for dir in "$TFTP_ROOT"/*/; do
	#    if [ -d "$dir" ]; then
	#        echo "➡️ Copying to $dir"
	#        sudo cp "$PI_firmware"/"$FIRMWARE_FILE" "$PI_firmware"/"$SIG_FILE" "$dir"
	#
	#    fi
	#done

	echo "Copying $FIRMWARE_FILE and $SIG_FILE to $TFTP_ROOT/$PI_Number..."
	echo "➡️ Copying to$TFTP_ROOT/$PI_Number"
	sudo cp "$PI_firmware"/"$FIRMWARE_FILE" "$TFTP_ROOT/$PI_Number"
	sudo cp "$PI_firmware"/"$SIG_FILE" "$TFTP_ROOT/$PI_Number"

	echo "Done! Firmware files placed in $TFTP_ROOT/$PI_Number:"
}

# [7 / 7]
netboot_cmdline_txt_nfsboot () {
	# --- Create cmdline.txt for NFS boot ---
	echo "📄 Creating cmdline.txt in $TFTP_ROOT/$PI_Number..."

	# Makes some progress to a root shell, not fully functional
	#NFS_CMDLINE_DEFAULT="dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=$STATIC_IP:$NFS_ROOT/$PI_Number,vers=3 rw ip=dhcp init=/bin/sh rootwait"

	# @source From https://raspberrytips.com/raspberry-pi-cmdline-txt/
	#NFS_CMDLINE_RASPBIAN_FIRSTBOOT_DISK="console=serial0,115200 console=tty1 root=PARTUUID=1d124286-02 rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspberrypi-sys-mods/firstboot splash plymouth.ignore-serial-consoles systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target"

	# derived from above
	#NFS_CMDLINE_RASPBIAN_FIRSTBOOT_NFS="console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=$STATIC_IP:$NFS_ROOT/$PI_Number,vers=3 rw ip=dhcp rootwait init=/usr/lib/raspberrypi-sys-mods/firstboot splash plymouth.ignore-serial-consoles systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target"

	# dervied from above
	# Works to boot to Systemd Emergency Mode, fails some disk services
	NFS_CMDLINE_RASPBIAN_BOOT_NFS="console=serial0,115200 console=tty1 root=/dev/nfs rootfstype=nfs nfsroot=$STATIC_IP:$NFS_ROOT/$PI_Number,vers=3 rw ip=dhcp rootwait splash init=/lib/systemd/systemd"

	echo "$NFS_CMDLINE_RASPBIAN_BOOT_NFS" > "$TFTP_ROOT/$PI_Number/cmdline.txt"

	# All subfolders... not needed for now
	#for dir in "$TFTP_ROOT"/*/; do
	#    if [ -d "$dir" ]; then
	#        echo "➡️ Copying to $dir"
	#        sudo cp "$TFTP_ROOT/cmdline.txt" "$dir"
	#    fi
	#done

	echo "✅ cmdline.txt created. Place any additional boot files in $TFTP_ROOT/$PI_Number."
}


# Modular control; launch certain functions only
if [ "$RUNMODE" == "--full" ]; then
	echo "Runmode: Netbuild Full"
elif [ "$RUNMODE" == "--fw-only" ]; then
	echo "Runmode: Netbuild Firmware Only"
	netboot_fw_eprom_bin_and_sig 
	exit $?
fi

# Full runmode; run all steps starting with [1 / 7]

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
    echo "❌ Cannot use primary interface '$DEFAULT_ROUTE_IF' for network boot!"
    exit 1
fi

# --- Configure network boot interface ---
echo "⚙️ Configuring network boot interface $INTERFACE..."
ip addr flush dev "$INTERFACE"
ip link set "$INTERFACE" up
ip addr add "$STATIC_IP"/"$SUBNET_MASK" dev "$INTERFACE"

# --- Install required packages ---
echo "[1/7] Installing packages..."
apt update
apt install -y dnsmasq nfs-kernel-server unzip wget util-linux rsync xz-utils git build-essential libssl-dev debootstrap qemu-user-static binfmt-support

# --- Create necessary directories ---
echo "[2/7] Creating directories..."
mkdir -p "$TFTP_ROOT" \
	 "$TFTP_ROOT/$PI_Number" \
	 "$NFS_ROOT" \
	 "$NFS_ROOT/$PI_Number" \
	 "$MOUNT_ROOT_DIR" \
	 "$MOUNT_BOOT_DIR" \
	 "$PI_firmware" \
	 "$PI_firmware"/rpi-eeprom \
	 "$TFTP_ROOT"/"$PI_Number"

# --- Configure dnsmasq ---
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

# --- Adding TFTP, NFS, DHCP to firewall --- 
echo "Configureing firewall"
sudo ufw allow 67/udp comment 'Allow DHCP requests'
sudo ufw allow 69/udp comment 'Allow TFTP requests'
sudo ufw allow 2049/tcp comment 'Allow NFS'
sudo ufw allow 111/tcp comment 'Allow RPCbind (NFS dependency)'
sudo ufw allow 111/udp comment 'Allow RPCbind (NFS dependency)'
sudo ufw status




# --- Download Raspberry Pi OS Lite image ---
echo "[5/7] Downloading Raspberry Pi OS Lite image..."
cd /srv/nfs
if [ ! -f "$XZ_FILE" ]; then
    echo "⬇️ Downloading Raspberry Pi OS Lite..."
    wget -O "$XZ_FILE" https://downloads.raspberrypi.com/raspios_lite_armhf_latest
fi

# --- Extract .img from XZ if needed ---
echo "[6/7] Extracting .img from XZ..."
IMG_FILE="${XZ_FILE%.xz}.img"

if [ -z "$XZ_FILE" ]; then
    echo "❌ XZ_FILE variable is empty."
    exit 1
fi
if [ ! -f "$XZ_FILE" ]; then
    echo "❌ File '$XZ_FILE' not found. Cannot extract."
    exit 1
fi
if [ -f "$IMG_FILE" ]; then
    echo "✅ $IMG_FILE already exists, skipping decompression."
else
    echo "📦 Decompressing $XZ_FILE..."
    xz -dckf "$XZ_FILE" > "$IMG_FILE"
    if [ ! -f "$IMG_FILE" ]; then
        echo "❌ Failed to extract .img from $XZ_FILE"
        exit 1
    fi
fi

# [6 / 7]
netboot_extract_img_partitions 

# [6.5 / 7] 
# --- Configure NFS exports ---
echo "[6.5 / 7 ( 4/7 )] Exporting NFS root..."

#sudo debootstrap --arch=arm64 --foreign bookworm "$NFS_ROOT/$PI_Number" "$DEBIAN_MIRROR"
#sudo cp /usr/bin/qemu-aarch64-static "$NFS_ROOT/$PI_Number/usr/bin/"
#sudo chroot "$NFS_ROOT/$PI_Number" /debootstrap/debootstrap --second-stage

#Setting up networking and hostname
#sudo mkdir -p "$NFS_ROOT/$PI_Number/etc/network/"
#sudo touch "$NFS_ROOT/$PI_Number/etc/network/interfaces"
sudo tee "$NFS_ROOT/$PI_Number/etc/network/interfaces" > /dev/null <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Overlay custom stashed files, per RPi 

cp /home/lab/NetBootPi/stash/$PI_Number/hostname "$NFS_ROOT/$PI_Number/etc/hostname"
cp /home/lab/NetBootPi/stash/$PI_Number/hosts "$NFS_ROOT/$PI_Number/etc/hosts"

#Setting root password via chroot..."
sudo cp /usr/bin/qemu-aarch64-static "$NFS_ROOT/$PI_Number/usr/bin/"
sudo chroot "$NFS_ROOT/$PI_Number" passwd || echo "Skipping root password set"
sudo rm "$NFS_ROOT/$PI_Number/usr/bin/qemu-aarch64-static"

echo "$NFS_ROOT/$PI_Number *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports
mkdir -p "$NFS_ROOT/$PI_Number"/bin "$NFS_ROOT/$PI_Number"/lib "$NFS_ROOT/$PI_Number"/etc
sudo systemctl enable --now nfs-server
exportfs -ra

# Disable unnecessary laggy services (local disk - currently no disk)
sudo ln -sf $NFS_ROOT/$PI_Number/dev/null $NFS_ROOT/$PI_Number/lib/systemd/system/systemd-remount-fs.service
# Update mount file / remove local disk mounts (currently no disk)
cp /home/lab/NetBootPi/stash/all/fstab $NFS_ROOT/$PI_Number/etc

# [7 / 7] 
netboot_fw_eprom_bin_and_sig 

# [7 / 7] 
netboot_cmdline_txt_nfsboot

# --- Restart services ---
echo "🔁 Restarting services..."
systemctl restart dnsmasq
systemctl restart nfs-server

# --- Verify interface IP ---
echo "🧪 Verifying IP assignment on $INTERFACE..."
if ! ip -4 addr show "$INTERFACE" | grep -q "$STATIC_IP"; then
    echo "❌ Failed to assign static IP to $INTERFACE."
    exit 1
fi

echo "✅ $INTERFACE has IP $STATIC_IP"
echo "🎉 Netboot environment is ready on interface: $INTERFACE"



