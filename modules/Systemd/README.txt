To edit the systemd files run:
    sudo nano /etc/systemd/system/docker-pull-zaraos.service
    sudo nano /etc/systemd/system/docker-pull-zaraos.timer

To test the files:
    sudo systemctl daemon-reload 
    sudo systemctl start docker-pull-zaraos.service 
    sudo journalctl -u docker-pull-zaraos.service

