#!/bin/bash

REPO="https://github.com/KoalbyMQP/infrastructure.git"
DEST="/opt/myfiles"

# Clone or pull latest
if [ -d "$DEST/.git" ]; then
    echo "Updating existing installation..."
    cd $DEST
    sudo git pull
else
    echo "Installing fresh..."
    sudo git clone $REPO $DEST
fi

# Set permissions
sudo chmod +x $DEST/*.sh

echo "Installation complete!"