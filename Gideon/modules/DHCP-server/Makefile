
# For RPi 1: 
#  make clean1
#  make netboot1

clean1:
	sudo rm -r /srv/tftp/78def64a
	sudo rm -r /srv/nfs/rpi-root/78def64a

netboot1fw:
	sudo /home/lab/NetBootPi/PI-NetBoot-Next.sh enp2s0 --fw-only

netboot1:
	sudo /home/lab/NetBootPi/PI-NetBoot-Next.sh enp2s0 --full

all:
	netboot1
