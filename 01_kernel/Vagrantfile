# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :otuslinux => {
        :box_name => "centos/7",
        :ip_addr => '192.168.11.101'
  },
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

      config.vm.define boxname do |box|

          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s

          #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset

          box.vm.network "private_network", ip: boxconfig[:ip_addr]

          box.vm.provider :virtualbox do |vb|
            vb.customize ["modifyvm", :id, "--memory", "4096"]
            vb.customize ["modifyvm", :id, "--cpus", 4]
          end

          # Shared folders
          config.vm.synced_folder "~/github/otus/otus-linux_kernel/", "/home/vagrant/otus-linux_kernel/"

 	  box.vm.provision "shell", inline: <<-SHELL

            mkdir -p ~root/.ssh
            cp ~vagrant/.ssh/auth* ~root/.ssh

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
	    umount /mnt
	    rm /tmp/VBoxGuestAdditions_6.0.14.iso

            # Install new kernel
            mkdir -p /usr/src/kernels/
            cd /usr/src/kernels/
            wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.3.8.tar.xz
            tar xvf linux-5.3.8.tar.xz
            rm linux-5.3.8.tar.xz
            cd linux-5.3.8/
            cp /boot/config-$(uname -r) .config
            sh -c 'yes "" | make oldconfig'
            make -j3
            make modules_install
            make -j3 install
            make clean

            # Update GRUB
            grub2-mkconfig -o /boot/grub2/grub.cfg
            grub2-set-default 0

          SHELL

          box.vm.provision :reload

       end
  end
end