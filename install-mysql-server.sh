#!/usr/bin/env bash

sudo dpkg -l mysql-server
if [ $? -ne 0 ]; then
	echo 'Installing MySQL server...'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password ""'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password ""'
	sudo apt-get install -y mysql-server
fi
