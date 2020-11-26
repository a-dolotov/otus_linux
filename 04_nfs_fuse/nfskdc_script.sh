#!/bin/bash

yum install -y krb5-libs krb5-server krb5-workstation expect

echo -e "192.168.50.12     nfskdc.testnfs.lan nfskdc\n\
192.168.50.10     nfss.testnfs.lan nfss\n\
192.168.50.11     nfsc.testnfs.lan nfsc"  >> /etc/hosts

timedatectl set-timezone Europe/Moscow

cp /home/vagrant/scripts/krb5.conf /etc/krb5.conf
sed -i 's/EXAMPLE.COM/TESTNFS.LAN/g' /var/kerberos/krb5kdc/kdc.conf
sed -i '/#master_key_type =/s/#//g' /var/kerberos/krb5kdc/kdc.conf

echo -e "root/admin@TESTNFS.LAN\t*\n\
vagrant/admin@TESTNFS.LAN\t*" > /var/kerberos/krb5kdc/kadm5.acl

chmod +x /home/vagrant/scripts/nfskdc_config.sh
/home/vagrant/scripts/nfskdc_config.sh
rm -r /home/vagrant/scripts*

kadmin.local -q "addprinc -pw "passvagrant" vagrant/admin"
kadmin.local -q "addprinc -pw "passroot" root/admin"
kadmin.local -q "addprinc -randkey nfs/nfss.testnfs.lan"
kadmin.local -q "addprinc -randkey nfs/nfsc.testnfs.lan"
kadmin.local -q "addprinc -pw "vagrant" vagrant"

systemctl enable --now krb5kdc kadmin

systemctl enable --now firewalld
firewall-cmd --permanent --add-service=kerberos
firewall-cmd --permanent --add-service=kadmin
firewall-cmd --reload
