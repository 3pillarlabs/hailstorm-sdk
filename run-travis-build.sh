#!/bin/bash

cd hailstorm-gem
HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" rspec
