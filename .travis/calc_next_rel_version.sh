#!/bin/bash

# Computes the version for the next release according to the following rules:
#
# *revision*
# This is the sum of the revisions of all components. If a revision is alphanumeric, the it is
# assumed that its format is /^(\d+)-?.*$/, and only the numeric part is considered.
#
# *minor*
# This is the sum of the minors of the CLI and WebApp components.
#
# *major*
# Major version is incremented by 1, if either the CLI major or WebApp major or both their major
# versions is updated in a release.

docker_id=$1
if [ -z "$docker_id" ]; then
  docker_id=$DOCKER_ID
fi

if [ -z "$docker_id" ]; then
  echo 'Need DOCKER_ID env variable or argument'
  exit 1
fi

fetch_version() {
  local component=$1
  local version=$(grep image $TRAVIS_BUILD_DIR/docker-compose.yml | grep $component | cut -f3 -d':' | cut -f1 -d'"')
  echo -n $version
}

calculate_revision() {
  local components="$*"
  local sum_revision=0
  for component in $components; do
    local version=$(fetch_version $component)
    local revision=$(echo $version | cut -f3 -d'.' | cut -f1 -d'-')
    sum_revision=$((${sum_revision}+${revision}))
  done
  echo -n $sum_revision
}

calculate_minor() {
  local components="$*"
  local sum_minor=0
  for component in $components; do
    local version=$(fetch_version $component)
    local minor=$(echo $version | cut -f2 -d'.')
    sum_minor=$((${sum_minor}+${minor}))
  done
  echo -n $sum_minor
}

calculate_major() {
  local components="$*"
  local sum_increments=0
  for component in $components; do
    local current_version=$(fetch_version $component)
    local current_major=$(echo $version | cut -f1 -d'.')
    local released_major=-1
    for tag in $($TRAVIS_BUILD_DIR/.travis/get_docker_versions.sh $docker_id $component | grep -v latest); do
      local tag_major=$(echo $tag | cut -f1 -d'.')
      if [ $released_major -lt $tag_major ]; then released_major=$tag_major; fi
    done

    local maj_incr=$(($current_major-$released_major))
    sum_increments=$(($sum_increments+$maj_incr))
  done

  local current_released_major=-1
  for tag in $(git tag --list); do
    local tag_major=$(echo $tag | cut -f2 -d'/' | cut -f1 -d'.')
    if [ $current_released_major -lt $tag_major ]; then current_released_major=$tag_major; fi
  done

  if [ $sum_increments -gt 0 ]; then
    current_released_major=$(($current_released_major+1))
  fi

  echo $current_released_major
}

main() {
  local components=$(grep image docker-compose.yml | cut -f2 -d':' | sed 's/"//' | cut -f2 -d'/' | sed 's/\s*//')
  local new_revision=$(calculate_revision $components)
  local new_minor=$(calculate_minor hailstorm-web-client hailstorm-cli)
  local new_major=$(calculate_major hailstorm-web-client hailstorm-cli)
  echo -n "${new_major}.${new_minor}.${new_revision}"
}

main
