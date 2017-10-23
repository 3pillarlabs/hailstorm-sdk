#!/usr/bin/env bash

which java
if [ $? -ne 0 ]; then
	echo 'Installing Java 8...'
	sudo add-apt-repository ppa:webupd8team/java
	sudo apt-get update
	sudo debconf-set-selections <<< 'oracle-java8-installer shared/accepted-oracle-license-v1-1 select true'
	sudo apt-get install -y oracle-java8-installer
fi
java -version
