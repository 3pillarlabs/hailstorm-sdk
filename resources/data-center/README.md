# Purpose
These resources are primarily meant for running integration tests for the Hailstorm data-center feature.

The ``Dockerfile`` can also be used to build Docker images to run on data-center machines. This is a considerably
easier process to ensure that the nodes in the data center are setup correctly to work with Hailstorm. However, note
that the Docker container enables SSH using an insecure key, it is essential that the SSH port be protected from
access outside the data-center.

## Linux
For Linux, use the Docker instances either directly or using Vagrant.

### Docker

#### Build an image
```bash
docker build -t hailstorm-data-center-node:latest .
```

#### Run the container and daemonize
```bash
docker run -it --rm --name hs-dc-node-1 -d hailstorm-data-center-node:latest
docker run -it --rm --name hs-dc-node-2 -d hailstorm-data-center-node:latest
```

### Vagrant
```bash
vagrant up hs-dc-node-1
vagrant up hs-dc-node-2
```

## MacOS

For MacOs, use the VirtualBox VMs using Vagrant.
```bash
vagrant up hs-dc-vm-1
vagrant up hs-dc-vm-2
```
