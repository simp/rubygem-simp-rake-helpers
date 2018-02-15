# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  config.vm.define 'simp-rake-helpers_test' do |config|
    config.vm.box = "centos/7"
    config.vm.provider "virtualbox" do |vb|
      # Customize the amount of memory on the VM:
      vb.memory = "1024"
    end


    config.vm.provision "shell", inline: <<-SHELL
      yum install --enablerepo=extras -y docker vim-enhanced git libicu-devel tree
      usermod -aG dockerroot vagrant
      cat <<DOCKAH > /etc/docker/daemon.json
  {
    "live-restore": true,
    "group": "dockerroot"
  }
DOCKAH
      chmod 0644 /etc/docker/daemon.json
      systemctl start docker
      systemctl enable docker
    SHELL


    # vagrant user
    config.vm.provision "shell", privileged: false, inline: <<-SHELL
      gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
      [ -f install_rvm.sh ] || curl -sSL https://get.rvm.io > install_rvm.sh
      bash install_rvm.sh stable '--with-default-gems=bundler beaker rake' --ruby=2.1.9
      source /home/vagrant/.rvm/scripts/rvm
      cd /vagrant
      bundle
    SHELL
  end
end
