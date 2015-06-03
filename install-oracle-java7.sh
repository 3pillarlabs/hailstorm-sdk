#!/usr/bin/env bash

which java
if [ $? -ne 0 ]; then
	echo 'Installing Java 7...'
	sudo add-apt-repository ppa:webupd8team/java
	sudo apt-get update
	sudo debconf-set-selections <<< 'oracle-java7-installer shared/accepted-oracle-license-v1-1 select true'
	sudo apt-get install -y oracle-java7-installer
	sudo update-java-alternatives -s java-7-oracle
	sudo apt-get install -y oracle-java7-set-default
fi
java -version


