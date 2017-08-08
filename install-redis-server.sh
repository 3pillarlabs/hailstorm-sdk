#!/usr/bin/env bash

# redis server
which redis-server >/dev/null 2>&1
if [ $? -ne 0 ]; then
  sudo apt-get install -y redis-server
fi
