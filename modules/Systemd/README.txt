To edit the systemd files run:
    sudo nano /etc/systemd/system/docker-pull-zaraos.service
    sudo nano /etc/systemd/system/docker-pull-zaraos.timer
    sudo nano /etc/systemd/system/slack-shutdown.service

To test the files:
    sudo systemctl daemon-reload 
    sudo systemctl start docker-pull-zaraos.service 
    sudo journalctl -u docker-pull-zaraos.service

For the slack systemd, it is harder to test since it will send a slack notif to the server, make sure to check the
environment variable for the slack url 