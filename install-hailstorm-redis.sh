#!/usr/bin/env bash

# install hailstorm-redis to ext-jruby-1.7.19@hailstorm

sudo -i

ruby_version='jruby@hailstorm'
install_path=/usr/local/lib
hailstorm_redis_home=$install_path/hailstorm-redis
vagrant_user=vagrant
rvm_script_path=/usr/local/rvm/scripts/rvm

source $rvm_script_path
cd $install_path
rvm use $ruby_version

# install bundler
which bundle
if [ $? -ne 0 ]; then
	gem install bundler --no-rdoc --no-ri
fi

# install hailstorm-redis & dependencies
cp /vagrant/Gemfile.hailstorm-redis $hailstorm_redis_home/Gemfile
chown -R $vagrant_user:$vagrant_user $hailstorm_redis_home
cd $hailstorm_redis_home
bundle install
echo $ruby_version > .ruby-version

# install upstart conf for sidekiq
cp /vagrant/sidekiq.conf /etc/init/sidekiq.conf
status sidekiq | grep 'stop' || stop sidekiq
start sidekiq

exit
