#!/usr/bin/env bash

# install ruby-mri & create 'hailstorm' gemset
sudo -i

source /usr/local/rvm/scripts/rvm

rvm list | grep 'ruby-2.4.1'
if [ $? -ne 0 ]; then
	rvm install ruby-2.4.1
	rvm use ruby-2.4.1
	rvm gemset create hailstorm
fi

exit
