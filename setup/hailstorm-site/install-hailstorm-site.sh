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
echo $ruby_version > .ruby-version
mysql -uroot hailstorm_site_production -e 'select id from products limit 1' > /dev/null 2>&1
if [ $? -ne 0 ]; then
	mysql -uroot <<< 'grant all privileges on *.* to "hailstorm"@"localhost" identified by "hailstorm"'
	RAILS_ENV=production rake db:setup
else
	RAILS_ENV=production rake db:migrate
fi
mkdir -p tmp/cache tmp/pids tmp/sessions tmp/sockets log
chown -R $vagrant_user:$vagrant_user $hailstorm_site_home
mkdir -p /usr/local/lib/hailstorm-site/tmp/sockets && chmod 770 /usr/local/lib/hailstorm-site/tmp/sockets
chown $vagrant_user:$vagrant_user /usr/local/lib/hailstorm-site/tmp/sockets
chmod 777 /usr/local/lib/hailstorm-site/tmp/sockets

# install systemd conf for unicorn
cp /vagrant/setup/hailstorm-site/hailstorm-site.service /etc/systemd/system/hailstorm-site.service
systemctl daemon-reload
systemctl enable hailstorm-site.service
systemctl stop hailstorm-site.service
sleep 2
systemctl start hailstorm-site.service


# set nginx-unicorn as default (root) site
rm -f /etc/nginx/sites-enabled/default # just a symlink
cp /vagrant/setup/hailstorm-site/hailstorm-site-nginx.conf /etc/nginx/sites-available/hailstorm-site
rm -f /etc/nginx/sites-enabled/hailstorm-site
ln -s /etc/nginx/sites-available/hailstorm-site /etc/nginx/sites-enabled/hailstorm-site
service nginx reload

# nmon for server monitoring
which nmon >/dev/null 2>&1 || apt-get install -y nmon

# authorize insecure_key.pub
vagrant_user_home="/home/$vagrant_user"
if [ ! -e $vagrant_user_home/insecure_key.pub ]; then
	sudo -u $vagrant_user mkdir -p $vagrant_user_home/.ssh
	sudo -u $vagrant_user chmod 700 $vagrant_user_home/.ssh
	sudo -u $vagrant_user cat /vagrant/setup/hailstorm-site/insecure_key.pub >> $vagrant_user_home/.ssh/authorized_keys
	sudo -u $vagrant_user chmod 400 $vagrant_user_home/.ssh/authorized_keys
	sudo -u $vagrant_user cp /vagrant/setup/hailstorm-site/insecure_key.pub $vagrant_user_home/.
fi

exit
