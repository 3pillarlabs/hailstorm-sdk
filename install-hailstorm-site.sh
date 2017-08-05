#!/usr/bin/env bash

# install hailstorm-site to ruby-2.4.1@hailstorm

sudo -i

# mysql2 gem dependencies
apt-get install -y libmysqlclient-dev

# nodejs
apt-get install -y nodejs

ruby_version='ruby-2.4.1@hailstorm'
install_path=/vagrant
hailstorm_site_home=$install_path/hailstorm-site
vagrant_user=vagrant
rvm_script_path=/usr/local/rvm/scripts/rvm

source $rvm_script_path
cd $install_path
rvm use $ruby_version

# install bundler if not present
which bundle
if [ $? -ne 0 ]; then
	gem install bundler --no-rdoc --no-ri
fi

# install hailstorm-site & dependencies
cd $hailstorm_site_home
bundle install
echo '@hailstorm' > .ruby-version

exit
