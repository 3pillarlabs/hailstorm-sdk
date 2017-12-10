# Introduction
``hailstorm-gem`` is the core Hailstorm library and CLI of the Hailstorm application suite.

# User Guide
Refer to the [Hailstorm Wiki](https://github.com/3pillarlabs/hailstorm-sdk/wiki) for the user guide.

# Developer Guide
Use the User Guide to setup your own Hailstorm virtual machine. Once this is done, create a development environment
in the virtual machine. SSH to the VM and -
```bash
cd /vagrant/hailstorm-gem
rvm gemset create hailstorm-dev
rvm use @hailstorm-dev
gem install --no-rdoc --no-ri bundler
bundle install
```

You are all set.

## Unit tests (specs)
```bash
rspec
```

## Integration tests
This requires an AWS account and a little more setup.

### AWS tests

```bash
cp features/data/keys-sample.yml features/data/keys.yml
```

Edit ``features/data/keys-sample.yml`` to add your AWS access and secret keys.

### Data Center tests
To execute the data-center integration tests, two nodes need to be setup.

**Note** - The ``resources/data-center/Dockerfile`` can also be used to build Docker images to run on data-center machines. 
This is a considerably easier process to ensure that the nodes in the data center are setup correctly to work with 
Hailstorm. However, note that the Docker container enables SSH using an insecure key, it is essential that the SSH port 
be protected from access outside the data-center.

### Linux
For Linux, use the Docker containers.

#### Build an image
```bash
cd resources/data-center
docker build -t hailstorm-data-center-node:latest .
```

#### Run the container and daemonize
```bash
docker run -it --rm --name hs-dc-node-1 -d hailstorm-data-center-node:latest
docker run -it --rm --name hs-dc-node-2 -d hailstorm-data-center-node:latest
```

Use ``docker inspect <container-id>`` to find the IP addresses.

### MacOS

For MacOs, use the VirtualBox VMs using Vagrant.
```bash
vagrant up hs-dc-vm-1
vagrant up hs-dc-vm-2
```
The IP addresses are ``192.168.27.10`` and ``192.168.27.20``.


### Configuration
Once the setup is done, copy ``features/data/data-center-machines-sample.yml`` to 
``features/data/data-center-machines.yml`` and add the IP addresses of the Docker containers or Vagrant VMs based on the
setup.

### Bring up the target sites

```bash
vagrant up site
vagrant up site-local
```

### Execution
```bash
# Important commands and options
cucumber --tag @smoke

# Common scenarios
cucumber --tag @end-to-end

# All scenarios
cucumber
```
