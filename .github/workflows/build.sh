#!/bin/bash

set -ev

RELEASE_VERSION=$1
PARENT_DIR=hailstorm-${RELEASE_VERSION}

mkdir -p ${PARENT_DIR}/hailstorm-web
mkdir -p ${PARENT_DIR}/hailstorm-cli
cd hailstorm-cli
make release_makefile
cd ../
mv hailstorm-cli/Makefile.release ${PARENT_DIR}/hailstorm-cli/Makefile
cp docker-compose-cli.yml ${PARENT_DIR}/hailstorm-cli/docker-compose.yml
cp docker-compose.yml ${PARENT_DIR}/hailstorm-web/docker-compose.yml
tar -czf ${PARENT_DIR}.tar.gz ${PARENT_DIR}/
