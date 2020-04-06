# Developer Guide

``hailstorm-api`` provides the API for the web clients.

## Pre-requisites

- docker
- docker-compose
- openjdk-8
- rvm (recommended for development)

## Installation

``hailstorm-api`` depends on ``hailstorm-gem``. The gem needs to be built manually before building the API. Check the
``hailstorm-gem`` README for installing the gem in its own gemset.

```bash
# still in the hailstorm-gem directory
➜  hailstorm-gem$ make build
# this will generate a gem in the hailstorm-gem/pkg directory

# switching over to hailstorm-api
➜  hailstorm-gem$ cd ../hailstorm-api
➜  hailstorm-api$ rvm gemset create hailstorm-api
➜  hailstorm-api$ rvm use jruby-9.1.17.0@hailstorm-api
➜  hailstorm-api$ echo jruby-9.1.17.0@hailstorm-api > .ruby-version

# Install the Hailstorm gem
➜  hailstorm-api$ gem install ../hailstorm-gem/pkg/*.gem
➜  hailstorm-api$ make install
```

## Unit tests (rspec)

```bash
docker-compose up -d hailstorm-db
docker-compose logs -f
# wait for database to initialize and CTRL+C
make test
```
### Coverage

```bash
make coverage
```
Coverage report is generated in ``coverage`` directory.
