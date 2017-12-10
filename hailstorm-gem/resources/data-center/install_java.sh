#!/usr/bin/env bash
add-apt-repository ppa:webupd8team/java && \
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
apt-get update && \
apt-get install -y oracle-java8-installer && \
apt-get clean && \
rm -rf /var/lib/apt/lists/*
