#!/usr/bin/env bash
add-apt-repository -y ppa:openjdk-r/ppa && \
apt-get update && \
apt-get install -y openjdk-8-jre-headless && \
apt-get clean && \
rm -rf /var/lib/apt/lists/*
