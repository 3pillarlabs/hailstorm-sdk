#!/usr/bin/env bash

VAGRANT_USER=vagrant

# install RVM unless it is already installed
if [ ! -d /usr/local/rvm ]; then
	echo 'Fetching GPG keys for RVM...'
	sudo gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys \
	409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

	echo 'Fetching and installing RVM...'
	curl -sSL https://get.rvm.io | sudo bash -s $1

	echo "Creating 'rvm' group if it does not exist..."
	sudo grep -e '^rvm' /etc/group || sudo groupadd rvm
	echo "Adding ${VAGRANT_USER} to 'rvm' group..."
	sudo usermod -a -G rvm ${VAGRANT_USER}
fi
