#!/bin/bash

DOCKER_REPO=$1
RELEASE_VERSION=$2

cat - > Makefile.release <<EOM
.PHONY: run_cli
run_cli:
	docker run \\
	-it \\
	--rm \\
	--network hailstorm-sdk_hailstorm \\
	-e DATABASE_HOST=hailstorm-db \\
	-v \${PWD}:/hailstorm \\
	hailstorm3/${DOCKER_REPO}:${RELEASE_VERSION} dockerize -wait tcp://hailstorm-db:3306 bash
EOM
