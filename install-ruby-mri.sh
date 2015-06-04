#!/usr/bin/env bash

# install ruby-mri & create 'hailstorm' gemset
sudo -i

source /usr/local/rvm/scripts/rvm
rvm list | grep 'ruby-2.1.4'
if [ $? -ne 0 ]; then
	rvm install ruby-2.1.4
	rvm use ruby-2.1.4
	rvm gemset create hailstorm
fi

exit

