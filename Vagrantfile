config# -*- mode: ruby -*-
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

  config.vm.provision "sync_clock", :type => :shell, :inline => 'ntpdate ntp.ubuntu.com', :run => 'always'

  config.vm.provision "vagrant_user", :type => :shell, :path => 'setup/create_vagrant_user.sh'

  config.vm.provision "apt", :type => :shell, :inline => <<-SHELL
    last_apt_update_path=/var/cache/last_apt_update
    if [ ! -e $last_apt_update_path ] || [ `expr $(date "+%s") - $(stat -c "%Y" $last_apt_update_path)` -gt 86400 ]; then
      apt-get update && touch $last_apt_update_path
    fi
  SHELL

	# mysql-server
	config.vm.provision "mysql", :type => :shell, :path => 'setup/install-mysql-server.sh'

	# nginx
	config.vm.provision "nginx", :type => :shell, :inline => <<-SHELL
    which nginx >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      sudo apt-get install -y nginx
    fi
  SHELL

	# rvm
	config.vm.provision "rvm", :type => :shell, :path => 'setup/ruby/install-rvm.sh', :args => 'stable'

	# git
	config.vm.provision "git", :type => :shell, :inline => 'sudo apt-get install -y git'

	# ruby-mri
	config.vm.provision "mri", :type => :shell, :path => 'setup/ruby/install-ruby-mri.sh'

  def common_provision(config)
  	# redis-server
  	config.vm.provision "redis", :type => :shell, :path => 'setup/redis/install-redis-server.sh'

  	# oracle java
  	config.vm.provision "java", :type => :shell, :path => 'setup/install-oracle-java.sh'

  	# jruby
  	config.vm.provision "jruby", :type => :shell, :path => 'setup/ruby/install-jruby.sh'

    # hailstom-apps
  	config.vm.provision "hailstorm_apps", :type => :shell, :path => 'setup/install-hailstorm-apps.sh', :run => 'always'

  	# hailstorm-redis
  	config.vm.provision "hailstorm_redis", :type => :shell, :path => 'setup/redis/install-hailstorm-redis.sh'

  	# hailstorm-web
  	config.vm.provision "hailstorm_web", :type => :shell, :path => 'setup/hailstorm-web/install-hailstorm-web.sh'
  end

  config.vm.define "dev", :primary => true do |dev|
    dev.vm.box = "ubuntu/trusty64"
  	dev.vm.provider "virtualbox" do |vb|
    #   # Display the VirtualBox GUI when booting the machine
    #   vb.gui = true
    #
  		# Customize the amount of memory on the VM:
  		vb.memory = "2048"
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
  	end
    dev.vm.network "private_network", ip: "192.168.17.10"
    dev.vm.network 'forwarded_port', :guest => 80, :host => 8080, :autocorrect => true
    common_provision(dev)
  end

  def aws_keys
    credentials_file_path = File.join(ENV['HOME'], '.aws', 'credentials')
    if File.exist?(credentials_file_path)
      keys = File.open(credentials_file_path, 'r') do |f|
        f.readlines.collect {|line|
          line.chomp
        }
        .reduce({}) {|k, e|
            if e =~ /^\[(.+?)\]$/
              profile = $1
              k.merge(profile => {}, last: profile)
            elsif e =~ /^(.+?)\s*=\s*['"]?(.+?)['"]?$/
              profile = k[:last]
              k[profile][$1] = $2
              k
            else
              k
            end
        }
      end
      profile = keys.fetch(ENV['AWS_PROFILE'] || 'default')
      [profile['aws_access_key_id'], profile['aws_secret_access_key']]
    else
      raise "#{credentials_file_path} not found"
    end
  end

  config.vm.define "aws", autostart: false do |aws|
    aws.vm.box = "dummy"
    aws.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: [".git/", ".gitignore/"]

    aws.vm.provider :aws do |ec2, override|
      ec2.ami = "ami-841f46ff"
      ec2.access_key_id, ec2.secret_access_key = aws_keys()
      aws_conf = YAML.load_file('vagrant-aws.yml').reduce({}) { |a, e| a.merge(e[0].to_sym => e[1]) }
      ec2.keypair_name = aws_conf[:keypair_name]
      ec2.instance_type = aws_conf[:instance_type] || "t2.medium"
      ec2.elastic_ip = true
      ec2.region = aws_conf[:region] || "us-east-1"
      ec2.security_groups = aws_conf[:security_groups]
      ec2.subnet_id = aws_conf[:subnet_id] if aws_conf.key?(:subnet_id)
      ec2.tags = {
        Name: "Vagrant - Hailstorm Web"
      }
      ec2.terminate_on_shutdown = false
      ec2.block_device_mapping = [{"DeviceName" => "/dev/sda1", "Ebs.VolumeSize" => 80}]

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = aws_conf[:private_key_path]
    end

    common_provision(aws)
  end

  config.vm.define "site", autostart: false do |site|
    site.vm.box = "dummy"
    site.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: [".git/", ".gitignore/", "log/", "tmp/"]

    site.vm.provider :aws do |ec2, override|
      ec2.ami = "ami-841f46ff"
      ec2.access_key_id, ec2.secret_access_key = aws_keys()
      require 'yaml'
      aws_conf = YAML.load_file('vagrant-site.yml').reduce({}) { |a, e| a.merge(e[0].to_sym => e[1]) }
      ec2.keypair_name = aws_conf[:keypair_name]
      ec2.instance_type = aws_conf[:instance_type] || "t2.medium"
      ec2.elastic_ip = true
      ec2.region = aws_conf[:region] || "us-east-1"
      ec2.security_groups = aws_conf[:security_groups]
      ec2.subnet_id = aws_conf[:subnet_id] if aws_conf.key?(:subnet_id)
      ec2.tags = {
        Name: "Vagrant - Hailstorm Site"
      }
      ec2.terminate_on_shutdown = false

      ec2.block_device_mapping = [{"DeviceName" => "/dev/sda1", "Ebs.VolumeSize" => 80}]

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = aws_conf[:private_key_path]
    end

  	# hailstorm-site
  	site.vm.provision "hailstorm_site", :type => :shell, :path => 'setup/hailstorm-site/install-hailstorm-site.sh', :run => 'always'
  end

	config.vm.define "site-local" do |site_local|
		site_local.vm.box = "ubuntu/trusty64"
		site_local.vm.provider "virtualbox" do |vb|
		#   Display the VirtualBox GUI when booting the machine
		#   vb.gui = true
		#
			# Customize the amount of memory on the VM:
			vb.memory = "2048"
			vb.cpus = 2
			vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
		end
		site_local.vm.network "private_network", ip: "192.168.20.100"

  	# hailstorm-site
  	site_local.vm.provision "hailstorm_site", :type => :shell, :path => 'install-hailstorm-site.sh', :run => 'always'
  end
end
