# Hailstorm Virtual Machine

``hailstorm-vm`` is a virtual machine creator for the Hailstorm suite of applications. The virtual machine contains both the CLI and web applications.

## Software Prerequisites

1. Vagrant - This project was developed using version _1.8.1_, recommend same or higher version.
1. For local setup, you'll need VirtualBox. Depending on how you install Vagrant, VirtualBox may be bundled with the Vagrant setup.
1. For the AWS setup, you need to install the ``vagrant-aws`` plugin. Follow the instructions from the [project page](https://github.com/mitchellh/vagrant-aws).

# Setup
Follow these steps for a development or release setup. If you plan to use Hailstorm for performance testing, use the realease steps, starting with the common section.

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
