#!/bin/sh
# Exits with zero status code if the docker image/name:tag is not in the container registry.

docker_id=$1
docker_repo=$2
docker_tag=$3

curl -sf "https://registry.hub.docker.com/v2/repositories/${docker_id}/${docker_repo}/tags/" | \
jq -r '."results"[]["name"]' | \
grep "${docker_tag}" >/dev/null 2>&1

test $? -ne 0
