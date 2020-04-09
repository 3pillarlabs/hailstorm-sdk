#!/bin/sh

set -ev

bundle exec rake db:setup

bundle exec rake db:migrate

exec bundle exec rackup -o 0.0.0.0 -p 80 -E container
