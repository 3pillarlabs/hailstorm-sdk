# Developer Guide
``hailstorm-cli`` is the CLI of the Hailstorm application suite.

## Pre-requisites

- docker
- docker-compose
- openjdk-8
- rvm (recommended for development)
- vagrant (needed for running integration tests)

## Installation

``hailstorm-cli`` depends on ``hailstorm-gem``. The gem needs to be built manually before building the CLI. Check the
``hailstorm-gem`` README for installing the gem in its own gemset.

```bash
# still in the hailstorm-gem directory
➜  hailstorm-gem$ make build
# this will generate a gem in the hailstorm-gem/pkg directory

# switching over to hailstorm-cli
➜  hailstorm-gem$ cd ../hailstorm-cli
➜  hailstorm-cli$ rvm gemset create hailstorm-cli
➜  hailstorm-cli$ rvm use jruby-9.2.11.1@hailstorm-cli
➜  hailstorm-cli$ echo jruby-9.2.11.1@hailstorm-cli > .ruby-version

# Install the Hailstorm gem
➜  hailstorm-cli$ gem install ../hailstorm-gem/pkg/*.gem
➜  hailstorm-cli$ make install
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

## Integration tests
This requires an AWS account and a little more setup. Ensure your AWS account has a VPC with a public subnet.

### Bring up the target site

Download or clone the [Hailstorm Site repository](https://github.com/3pillarlabs/hailstorm-site) and follow its
README to set up the target system on AWS.

```bash
➜  hailstorm-site$ vagrant up aws-site --provider=aws
```

### Data Center Simulation

Bring up the docker containers that simulate a data center.
```bash
# If you are following from the unit test instructions or have docker-compose up previously, stop the containers first
#➜  hailstorm-sdk$ docker-compose down
➜  hailstorm-sdk$ docker-compose -f docker-compose-cli.yml -f docker-compose-cli.ci.yml -f docker-compose.dc-sim.yml up -d
```
This will bring up 3 containers in addition to the database - one container acts as the target system and two as load
generating agents.

#### Data Center Simulation on Vagrant

This is an alternate setup of a local data center for simulation. It uses virtual machines instead of containers. Follow
the README in [Hailstorm Site repository](https://github.com/3pillarlabs/hailstorm-site). This is the recommended way to
simulate the data center to collect performance statistics instead of raw functionality checks.

### AWS keys

```bash
# change directory to CLI
➜  hailstorm-sdk$ cd hailstorm-cli
➜  hailstorm-cli$ cp features/data/keys-sample.yml features/data/keys.yml
```
Edit ``features/data/keys.yml`` to add your AWS access and secret keys.

Copy the private key file to one with ``.pem`` suffix.
```bash
cp features/data/insecure_key features/data/insecure_key.pem
```

### Execution

Verify the docker containers have initialized successfully.
```bash
docker-compose logs -f
# check if the containers initialized, wait till there is no more activity, and CTRL+C to interrupt.
```

```bash
# Important commands and options
bundle exec cucumber --tag @smoke

# Common scenarios
bundle exec cucumber --tag @end-to-end

# All scenarios
bundle exec cucumber
```

### Post execution

Bring down the docker containers.
```bash
➜  hailstorm-cli$ cd ../
➜  hailstorm-sdk$ docker-compose -f docker-compose-cli.yml -f docker-compose-cli.ci.yml -f docker-compose.dc-sim.yml down
```

Bring down the target site.
```bash
➜  hailstorm-site$ vagrant halt aws-site
```

or delete it completely
```bash
➜  hailstorm-site$ vagrant destroy aws-site
```
