# Hailstorm SDK

This SDK has all the Hailstorm applications -
* hailstorm-gem
* hailstorm-redis
* hailstorm-web

This SDK can be used to create a virtual machine that contains all the applications.

## Software Prerequisites

1. Vagrant - This project was developed using version _1.8.1_, recommend same or higher version.
1. For local setup, you'll need VirtualBox. Depending on how you install Vagrant, VirtualBox may be bundled with the Vagrant setup.
1. For the AWS setup, you need to install the ``vagrant-aws`` plugin. Follow the instructions from the [project page](https://github.com/mitchellh/vagrant-aws).

## Setup
Follow these steps for a development or release setup. If you plan to use Hailstorm for performance testing, use the release setup.

### Development

#### Local VM
```bash
vagrant up dev
```
This will take a long time for creating and provisioning the VM with everything you need, so you can refill your coffee if you'd like!

##### Hailstorm CLI

If you want to use the CLI interface, SSH into the VM, once the VM has been provisioned successfully -
```bash
vagrant ssh dev
```
This will open a SSH session.

Next, set the hailstorm environment -
```bash
rvm use @hailstorm
```
You need to do this every time you SSH into the VM.

Suppose you wanted to create a new Hailstorm project named ``getting_started`` -
```bash
/vagrant/hailstorm-gem/bin/hailstorm -g /vagrant/hailstorm-gem getting_started
```

This will create the skeleton structure. To get started with your project -
```
cd getting_started
bundle check
./script/hailstorm
```
This should display the Hailstorm prompt.

#### hailstorm-gem Development

Creating the environment for hacking on the gem development is simple. Make sure you are in a JRuby VM and -
```
rvm gemset create hailstorm-gem-dev
rvm use @hailstorm-gem-dev
gem install --no-rdoc --no-ri bundler
bundle install
```
The next time you log into the VM, just ``rvm use @hailstorm-gem-dev``.


### Release

TBD
