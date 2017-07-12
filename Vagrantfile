# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/trusty64"

  config.vm.define "dev", :primary => true do |dev|
  	dev.vm.provider "virtualbox" do |vb|
    #   # Display the VirtualBox GUI when booting the machine
    #   vb.gui = true
    #
  		# Customize the amount of memory on the VM:
  		vb.memory = "2048"
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
  	end
  end

	# STACK
	#
	# +--------------------+   +------------------------------------------+
	# |  ***************** |   |  *******************  *****************  |
	# |  * hailstorm-web * |   |  * hailstorm-redis *  * hailstorm-gem *  |
	# |  ***************** |   |  *******************  *****************  |
	# |                    |   |                                          |
	# |   ***********      |   |    ***********                           |
	# |   * unicorn *      |   |    * sidekiq *                           |
	# |   ***********      |   |    ***********                           |
	# |                    |   |                                          |
	# |ruby-2.14@hailstorm |   |           jruby-1.7.9@hailstorm          |
	# |                    |   |               Oracle Java 7              |
	# +--------------------+   +------------------------------------------+
	#    *********                  ****************
	#    * Nginx *                  * Redis Server *
	#    *********                  ****************
	#
	#                  ****************
	#                  * Mysql Server *
	#                  ****************
	# Tools:
	#   git
	#   npm

  config.vm.provision "apt", :type => :shell, :inline => <<-SHELL
    last_apt_update_path=/var/cache/last_apt_update
    if [ ! -e $last_apt_update_path ] || [ `expr $(date "+%s") - $(stat -c "%Y" $last_apt_update_path)` -gt 86400 ]; then
      apt-get update && touch $last_apt_update_path
    fi
  SHELL

  config.vm.provision "vagrant_user", :type => :shell, :path => 'create_vagrant_user.sh'

	# mysql-server
	config.vm.provision "mysql", :type => :shell, :path => 'install-mysql-server.sh'

	# redis-server
	config.vm.provision "redis", :type => :shell, :inline => <<-SHELL
    which redis-server >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      sudo apt-get install -y redis-server
    fi
  SHELL

	# nginx
	config.vm.provision "nginx", :type => :shell, :inline => <<-SHELL
    which nginx >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      sudo apt-get install -y nginx
    fi
  SHELL

	config.vm.network 'forwarded_port', :guest => 80, :host => 8080, :autocorrect => true

	# oracle java 7
	config.vm.provision "java", :type => :shell, :path => 'install-oracle-java.sh'

	# rvm
	config.vm.provision "rvm", :type => :shell, :path => 'install-rvm.sh', :args => 'stable'

	# git
	config.vm.provision "git", :type => :shell, :inline => 'sudo apt-get install -y git'

	# jruby
	config.vm.provision "jruby", :type => :shell, :path => 'install-jruby.sh'

	# ruby-mri
	config.vm.provision "mri", :type => :shell, :path => 'install-ruby-mri.sh'

	# hailstorm-redis
	config.vm.provision "hailstorm_redis", :type => :shell, :path => 'install-hailstorm-redis.sh'

	# hailstorm-web
	config.vm.provision "hailstorm_web", :type => :shell, :path => 'install-hailstorm-web.sh'

  config.vm.define "awsdemo", autostart: false do |demo|
    demo.vm.box = "dummy"
    demo.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: [".git/", ".gitignore/"]

    demo.vm.provider :aws do |aws, override|
      aws.access_key_id = ENV['AWS_ACCESS_KEY_ID']
      aws.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
      aws.keypair_name = "all_purpose"

      aws.ami = "ami-fce3c696"

      aws.instance_type = "t2.medium"
      aws.elastic_ip = true
      aws.region = "us-east-1"
      aws.security_groups = ["sg-0ca04c74"]
      aws.subnet_id = "subnet-f1e550a8"
      aws.tags = {
        Name: "Vagrant - Hailstorm Web"
      }
      aws.terminate_on_shutdown = false

      aws.block_device_mapping = [{"DeviceName" => "/dev/sda1", "Ebs.VolumeSize" => 80}]

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = "all_purpose.pem"
    end
  end

end
