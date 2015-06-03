#!/usr/bin/env bash

# install ruby-mri & create 'hailstorm' gemset
rvm list | grep '^ruby'
if [ $? -ne 0 ]; then
	sudo -i
	source /usr/local/rvm/scripts/rvm
	rvm install ruby-2.1.4
	rvm use ruby-2.1.4
	rvm gemset create hailstorm
	exit
fi

