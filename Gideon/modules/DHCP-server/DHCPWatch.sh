if [ $# -ne 1 ]; then
    echo "❌ Usage: $0 <Subnet_INTERFACE>"
    exit 1
fi
INTERFACE="$1"
sudo apt install tcpdump
sudo tcpdump -i $INTERFACE  -n -vvv
#port 67 or port 68
