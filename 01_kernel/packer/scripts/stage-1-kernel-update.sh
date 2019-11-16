#!/bin/bash

# Install vagrant default key
mkdir -pm 700 /home/vagrant/.ssh
curl -sL https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Install Pakages
yum update -y
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum groupinstall -y "Development Tools"
yum install -y dkms ncurses-devel hmaccalc zlib-devel binutils-devel elfutils-libelf-devel
yum install -y kernel-devel kernel-headers make gcc bc bison flex  openssl-devel grub2 wget perl

# Install VBoxGuestAdditions_6.0.14
curl -o /tmp/VBoxGuestAdditions_6.0.14.iso https://download.virtualbox.org/virtualbox/6.0.14/VBoxGuestAdditions_6.0.14.iso
mount -o loop /tmp/VBoxGuestAdditions_6.0.14.iso /mnt
/mnt/VBoxLinuxAdditions.run

mkdir -p /usr/src/kernels/
cd /usr/src/kernels/
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.3.8.tar.xz
tar xvf linux-5.3.8.tar.xz
rm linux-5.3.8.tar.xz
cd linux-5.3.8/
cp /boot/config-$(uname -r) .config
sh -c 'yes "" | make oldconfig'
make -j5
make modules_install
make -j5 install
make clean

# Remove older kernels (Only for demo! Not Production!)
# rm -f /boot/*3.10*

# Update GRUB
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0

# Reboot VM
shutdown -r now
