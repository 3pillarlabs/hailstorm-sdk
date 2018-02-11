#!/usr/bin/env bash

# install jruby & create 'hailstorm' gemset
sudo -i

jruby_version='9.1.7.0'
source /usr/local/rvm/scripts/rvm
rvm list | grep "$jruby_version"
if [ $? -ne 0 ]; then
	rvm install jruby-$jruby_version
	rvm use jruby-$jruby_version
	rvm gemset create hailstorm

	# chamge the rvm aliases
	for al in default jruby; do
		rvm alias list | grep $al
		if [ $? -eq 0 ]; then
			rvm alias delete $al
		fi
		rvm alias create $al jruby-$jruby_version
	done
fi

exit
