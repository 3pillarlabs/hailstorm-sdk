#!/usr/bin/env bash

# install hailstorm-web to ruby-2.1.4@hailstorm

sudo -i

# mysql2 gem dependencies
apt-get install -y libmysqlclient-dev

# nodejs
apt-get install -y nodejs

ruby_version='ruby-2.1.4@hailstorm'
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
if [ ! -e $hailstorm_web_home ]; then
	git clone -b develop http://labs.3pillarglobal.com:12000/hailstorm/hailstorm-web.git
	cp /vagrant/unicorn.conf.rb $hailstorm_web_home/unicorn.conf.rb
	cp /vagrant/hailstorm_prod_secret_kb $hailstorm_web_home/hailstorm_prod_secret_kb
	chown -R $vagrant_user:$vagrant_user $hailstorm_web_home
	cd $hailstorm_web_home
	bundle install
	echo $ruby_version > .ruby-version
	mysql -uroot -proot <<< 'grant all privileges on *.* to "hailstorm"@"localhost" identified by "hailstorm"'
	export HAILSTORM_WEB_DATABASE_PASSWORD=hailstorm
	RAILS_ENV=production rake db:setup
	mkdir -p tmp/cache tmp/pids tmp/sessions tmp/sockets
fi

# install upstart conf for unicorn
cp /vagrant/unicorn.conf /etc/init/unicorn.conf

# set nginx-unicorn as default (root) site
rm -f /etc/nginx/sites-enabled/default # just a symlink
cp /vagrant/nginx-unicorn.conf /etc/nginx/sites-available/hailstorm-web
ln -s /etc/nginx/sites-available/hailstorm-web /etc/nginx/sites-enabled/hailstorm-web

exit

