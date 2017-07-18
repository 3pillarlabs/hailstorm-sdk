# Hailstorm Virtual Machine

``hailstorm-vm`` is a virtual machine creator for the Hailstorm suite of applications. The virtual machine contains both the CLI and web applications.

## Software Prerequisites

1. Vagrant - This project was developed using version _1.8.1_, recommend same or higher version.
1. For local setup, you'll need VirtualBox. Depending on how you install Vagrant, VirtualBox may be bundled with the Vagrant setup.
1. For the AWS setup, you need to install the ``vagrant-aws`` plugin. Follow the instructions from the [project page](https://github.com/mitchellh/vagrant-aws).

# Setup
Follow these steps for a development or release setup. If you plan to use Hailstorm for performance testing, use the release steps, starting with the common section.

## Common
These steps are common for the development or release/production setup.
```bash
for sm in hailstorm-gem hailstorm-redis hailstorm-web; do
  git submodule update --init $sm
done
```
## Development
```bash
cd hailstorm-gem
git checkout dev
cd ../hailstorm-redis
git checkout develop
cd ../hailstorm-web
git checkout develop
cd ..
```

Once the git submodules have been initialized, its time to create your VM.

### Local VM
```bash
cd hailstorm-gem
vagrant up dev
```
This will take a long time for creating and provisioning the VM with everything you need, so you can refill your coffee if you'd like.

#### Hailstorm CLI

If you want to use the CLI interface, SSH into the VM, once the VM has been provisioned successfully -
```bash
vagrant ssh dev
```

This will open a SSH session. Suppose you wanted to create a new Hailstorm project named ``getting_started`` -
```bash
rvm use @hailstorm
/vagrant/hailstorm-gem/bin/hailstorm -g /vagrant/hailstorm-gem getting_started
```

This will create the skeleton structure. To get started with your project -
```
cd getting_started
bundle check
./script/hailstorm
```
This should display the Hailstorm prompt.
