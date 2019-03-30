# Hailstorm SDK



This SDK has all the Hailstorm applications -
* hailstorm-gem 
  [![Build Status](https://travis-ci.org/3pillarlabs/hailstorm-sdk.svg?branch=develop)](https://travis-ci.org/3pillarlabs/hailstorm-sdk)
  [![Maintainability](https://api.codeclimate.com/v1/badges/f6dc4763071d01bcd14e/maintainability)](https://codeclimate.com/github/3pillarlabs/hailstorm-sdk/maintainability)
  [![Test Coverage](https://api.codeclimate.com/v1/badges/f6dc4763071d01bcd14e/test_coverage)](https://codeclimate.com/github/3pillarlabs/hailstorm-sdk/test_coverage)
  
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

If you want to use the CLI interface, SSH into the VM, once the VM has been provisioned successfully, SSH to the VM.
```bash
vagrant ssh dev
```

To create a new Hailstorm project named ``getting_started`` -
```bash
hailstorm-cli getting_started
```

This will create the skeleton structure. To get started with your project -
```bash
cd getting_started
./script/hailstorm
```
This should display the Hailstorm prompt.
```
Welcome to the Hailstorm (version 4.0.0) shell.
Type help to get started...
hs >
```
