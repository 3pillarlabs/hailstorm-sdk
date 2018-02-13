#!/usr/bin/env bash

# install hailstorm-web to ruby-2.1.4@hailstorm

sudo -i

# mysql2 gem dependencies
apt-get install -y libmysqlclient-dev

# nodejs
apt-get install -y nodejs

ruby_version='ruby-2.4.1@hailstorm'
install_path=/usr/local/lib
hailstorm_web_home=$install_path/hailstorm-web
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

# install hailstorm-web & dependencies
cp /vagrant/setup/hailstorm-web/hailstorm-unicorn.conf.rb $hailstorm_web_home/unicorn.conf.rb
cp /vagrant/setup/hailstorm-web/hailstorm_prod_secret_kb $hailstorm_web_home/hailstorm_prod_secret_kb
cd $hailstorm_web_home
bundle install
echo $ruby_version > .ruby-version
mysql -uroot <<< 'grant all privileges on *.* to "hailstorm"@"localhost" identified by "hailstorm"'
export HAILSTORM_WEB_DATABASE_PASSWORD=hailstorm
RAILS_ENV=production rake db:setup
mkdir -p tmp/cache tmp/pids tmp/sessions tmp/sockets
chown -R $vagrant_user:$vagrant_user $hailstorm_web_home

# install upstart conf for unicorn
cp /vagrant/setup/hailstorm-web/hailstorm-web.conf /etc/init/hailstorm-web.conf
start hailstorm-web

# set nginx-unicorn as default (root) site
rm -f /etc/nginx/sites-enabled/default # just a symlink
cp /vagrant/setup/hailstorm-web/hailstorm-web-nginx.conf /etc/nginx/sites-available/hailstorm-web
if [ ! -e /etc/nginx/sites-enabled/hailstorm-web ]; then
	ln -s /etc/nginx/sites-available/hailstorm-web /etc/nginx/sites-enabled/hailstorm-web
	service nginx reload
fi

exit
