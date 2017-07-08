#!/usr/bin/env bash

sudo dpkg -l mysql-server
if [ $? -ne 0 ]; then
	echo 'Installing MySQL server...'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
	sudo apt-get install -y mysql-server
	mysql -uroot -proot <<< "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('');"
fi
