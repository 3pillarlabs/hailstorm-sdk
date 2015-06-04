#!/usr/bin/env bash

# install jruby-1.7.x & create 'hailstorm' gemset
sudo -i

source /usr/local/rvm/scripts/rvm
rvm list | grep 'jruby'
if [ $? -ne 0 ]; then
	jruby_home=/opt/jruby-1.7.19
	if [ ! -e $jruby_home ]; then
		mkdir -p $jruby_home
		wget -O- -q https://s3.amazonaws.com/jruby.org/downloads/1.7.19/jruby-bin-1.7.19.tar.gz | tar -xzC $jruby_home
	fi
	rvm mount $jruby_home/bin/jruby -n jruby-1.7.19
	rvm install ext-jruby-1.7.19
	rvm use ext-jruby-1.7.19
	rvm gemset create hailstorm
fi

exit
