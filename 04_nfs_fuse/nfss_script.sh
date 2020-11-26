!/bin/bash

yum install -y krb5-libs krb5-workstation nfs-utils nfs-utils-lib expect

echo -e "192.168.50.12     nfskdc.testnfs.lan nfskdc\n\
192.168.50.10     nfss.testnfs.lan nfss\n\
192.168.50.11     nfsc.testnfs.lan nfsc"  >> /etc/hosts

timedatectl set-timezone Europe/Moscow

cp /home/vagrant/scripts/krb5.conf /etc/krb5.conf

chmod +x /home/vagrant/scripts/nfss_keytab.sh
/home/vagrant/scripts/nfss_keytab.sh
rm -r /home/vagrant/scripts*

sed -i '/^#LOCKD_TCPPORT/s/#//g' /etc/sysconfig/nfs
sed -i '/^#LOCKD_UDPPORT/s/#//g' /etc/sysconfig/nfs
sed -i '/^#MOUNTD_PORT/s/#//g' /etc/sysconfig/nfs
sed -i '/^#STATD_PORT/s/#//g' /etc/sysconfig/nfs
echo 'SECURE_NFS=yes' >> /etc/sysconfig/nfs

systemctl enable --now rpcbind nfs-server nfs-lock nfs-idmap nfs-rquotad

mkdir -p /var/share_fstab/upload /var/share_systemd/upload
chmod -R 777 /var/share_fstab/upload /var/share_systemd/upload
chown nfsnobody: -R /var/share_systemd/

echo -e "/var/share_fstab  192.168.50.11(rw,sync,no_subtree_check)\n\
/var/share_systemd  nfsc.testnfs.lan(rw,sync,no_subtree_check,sec=krb5,anonuid=65534,anongid=65534,all_squash)" >> /etc/exports
exportfs -ra

systemctl enable --now firewalld
firewall-cmd --permanent --add-port=111/tcp
firewall-cmd --permanent --add-port=111/udp
firewall-cmd --permanent --add-port=2049/tcp
firewall-cmd --permanent --add-port=2049/udp
firewall-cmd --permanent --add-port=32803/tcp
firewall-cmd --permanent --add-port=32769/udp
firewall-cmd --permanent --add-port=892/tcp
firewall-cmd --permanent --add-port=892/udp
firewall-cmd --permanent --add-port=662/tcp
firewall-cmd --permanent --add-port=662/udp
firewall-cmd --permanent --add-port=875/tcp
firewall-cmd --permanent --add-port=875/udp
firewall-cmd --reload
