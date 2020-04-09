# Hailstorm Site

This the test application for integration testing of Hailstorm application components.

## AWS Build

Copy ``setup/hailstorm-site/vagrant-site-sample.yml`` to ``setup/hailstorm-site/vagrant-site.yml`` and edit the
properties.

```bash
➜  hailstorm-sdk$ vagrant up aws-site
```

## Docker Build

```bash
➜  hailstorm-sdk$ docker-compose -f docker-compose-cli.yml -f docker-compose-cli.ci.yml -f docker-compose.dc-sim.yml up -d
```
In addition to the Hailstorm database, this will bring up 3 containers - one container acts as the target system and
two as load generating agents.
