#!/bin/sh
# Exits with non-zero status code if the docker image/name:tag is in the container registry.

docker_id=$1
docker_repo=$2
docker_tag=$3

$TRAVIS_BUILD_DIR/.travis/get_docker_versions.sh $docker_id $docker_repo | grep "${docker_tag}" >/dev/null 2>&1

test $? -ne 0
