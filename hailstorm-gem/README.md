# Introduction
``hailstorm-gem`` is the core Hailstorm library.

# Developer Guide
```bash
docker-compose up hailstorm-db -d
cd hailstorm-gem
rvm gemset create hailstorm-dev
rvm use @hailstorm-dev
gem install --no-rdoc --no-ri bundler
make install
```

## Unit tests (specs)
```bash
make test
```

## Integration tests
This requires an AWS account and a little more setup. Ensure your AWS account has a VPC with a public subnet.

### AWS tests

```bash
cp features/data/keys-sample.yml features/data/keys.yml
```

Edit ``features/data/keys.yml`` to add your AWS access and secret keys.

#### Bring up the target site

Copy ``setup/hailstorm-site/vagrant-site-sample.yml`` to ``setup/hailstorm-site/vagrant-site.yml`` and edit the
properties.

```bash
vagrant up aws-site
```

### Data Center tests

```bash
vagrant up /data-center/
```
This will bring up 3 virtual machines, one that acts as the target system and two load generating agents.

### Execution
```bash
# Important commands and options
cucumber --tag @smoke

# Common scenarios
cucumber --tag @end-to-end

# All scenarios
cucumber
```

### Unit test coverage

```bash
make coverage
```
Coverage report is generated in ``coverage`` directory.
