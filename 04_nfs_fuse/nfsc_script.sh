#!/bin/bash

yum install -y krb5-libs krb5-workstation nfs-utils nfs-utils-lib expect

echo -e "192.168.50.12     nfskdc.testnfs.lan nfskdc\n\
192.168.50.10     nfss.testnfs.lan nfss\n\
192.168.50.11     nfsc.testnfs.lan nfsc"  >> /etc/hosts

timedatectl set-timezone Europe/Moscow

cp /home/vagrant/scripts/krb5.conf /etc/krb5.conf

chmod +x /home/vagrant/scripts/nfsc_keytab.sh
/home/vagrant/scripts/nfsc_keytab.sh

cp /home/vagrant/scripts/mnt-share_systemd.mount /etc/systemd/system/
rm -r /home/vagrant/scripts*

echo 'SECURE_NFS=yes' >> /etc/sysconfig/nfs

mkdir /mnt/share_fstab/ /mnt/share_systemd/

echo "192.168.50.10:/var/share_fstab /mnt/share_fstab nfs udp,rw,sync,hard,intr,nfsvers=3,noauto,x-systemd.automount,x-systemd.mount-timeout=30,_netdev 0 0" >> /etc/fstab

systemctl daemon-reload
systemctl enable --now mnt-share_systemd.mount

systemctl enable --now firewalld

/sbin/shutdown -r now
