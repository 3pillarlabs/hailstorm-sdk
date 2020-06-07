#!/bin/sh

docker_id=$1
docker_repo=$2

curl -sf "https://registry.hub.docker.com/v2/repositories/${docker_id}/${docker_repo}/tags/" | \
jq -r '."results"[]["name"]'
