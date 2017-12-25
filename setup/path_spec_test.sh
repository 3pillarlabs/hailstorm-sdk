#!/usr/bin/env bash
# tests every path in setup is referenced correctly in the setup files
for fpath in $(find setup -type f); do
  bn=$(basename $fpath)
  bn_count=$(find . \( -name Vagrantfile -o \( -path './setup*' -type f \) \) -exec grep $bn {} + | wc -l)
  fp_count=$(find . \( -name Vagrantfile -o \( -path './setup*' -type f \) \) -exec grep $fpath {} + | wc -l)
  if [ $bn_count -eq $fp_count ]; then
    echo -n "."
  else
    echo
    echo "F $fpath"
    find . \( -name Vagrantfile -o \( -path './setup*' -type f \) \) -exec grep -n $bn {} +
  fi
done
