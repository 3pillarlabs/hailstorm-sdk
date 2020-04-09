#!/bin/bash

DOCKER_REPO=$1
RELEASE_VERSION=$2

cat - > Makefile.release <<EOM
DOCKER_PREFIX = \$(shell basename \${PWD})

.PHONY: run_cli
run_cli:    
	docker run \\
	-it \\
	--rm \\
	--network \${DOCKER_PREFIX}_hailstorm \\
	-e DATABASE_HOST=hailstorm-db \\
	-e HAILSTORM_WORKSPACE_ROOT=/hailstorm \\
	--mount type=bind,source=\$\${PWD},target=/hailstorm \\
	--mount type=volume,source=hailstorm-home,target=/home \\
	hailstorm3/${DOCKER_REPO}:${RELEASE_VERSION} dockerize -wait tcp://hailstorm-db:3306 \\
	bash -c 'chmod 777 /hailstorm && cd /hailstorm && su hailstorm'
EOM
