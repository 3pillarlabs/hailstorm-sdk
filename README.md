# Hailstorm SDK

[![Build Status](https://travis-ci.org/3pillarlabs/hailstorm-sdk.svg?branch=master)](https://travis-ci.org/3pillarlabs/hailstorm-sdk)

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
Follow these steps for a development or release setup. If you plan to use Hailstorm for performance testing, use the release setup. First you need to create the VM -
```bash
vagrant up dev
```
This will take a long time for creating and provisioning the VM with everything you need, so you can refill your coffee if you'd like!

### Release
Follow these steps for performance testing an application -

#### Hailstorm CLI

If you want to use the CLI interface, SSH into the VM, once the VM has been provisioned successfully -
```bash
vagrant ssh dev
```
This will open a SSH session.

Next, set the hailstorm environment -
```bash
rvm use @hailstorm
```
You need to do this every time you SSH into the VM, you might want to add it to ``~/.bashrc`` or ``~/.bash_profile``.

Suppose you wanted to create a new Hailstorm project named ``getting_started`` -
```bash
/vagrant/hailstorm-gem/bin/hailstorm -g /vagrant/hailstorm-gem getting_started
```

This will create the skeleton structure. To get started with your project -
```bash
cd getting_started
bundle check
./script/hailstorm
```
This should display the Hailstorm prompt.
