# Developer Guide
``hailstorm-gem`` is the core Hailstorm library.

## Pre-requisites

- docker
- docker-compose
- openjdk-8
- rvm (recommended for development)

## Installation

Instructions to build a local environment for the gem.

### RVM

Install latest jruby-9.1 and replace @global bundler v2.1.4 with v.2.0.1.

```bash
rvm install jruby-9.1.17.0
rvm use jruby-9.1.17.0@global
gem uninstall -x bundler
gem install bundler -v 2.0.1
```

### Rest of the setup

```bash
cd hailstorm-gem
rvm gemset create hailstorm-gem
rvm use jruby-9.1.17.0@hailstorm-gem
echo jruby-9.1.17.0@hailstorm-gem > .ruby-version
make install
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

## Integration tests (cucumber)
This requires an AWS account and a little more setup. Ensure your AWS account has a VPC with a public subnet.

```bash
cp features/data/keys-sample.yml features/data/keys.yml
```

Edit ``features/data/keys.yml`` to add your AWS access and secret keys.

### Execution
```bash
# Important commands and options
cucumber --tag @smoke

# Common scenarios
cucumber --tag @end-to-end

# All scenarios
cucumber
```
