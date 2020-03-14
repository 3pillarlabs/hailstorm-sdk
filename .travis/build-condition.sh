#!/bin/bash

if [[ -z $1 ]]; then
  echo "Commit range is required"
  exit 1
fi

if [[ -z $2 ]]; then
  echo "Change path is required"
fi

git diff --name-only $1 | sort -u | uniq | grep $2 > /dev/null
