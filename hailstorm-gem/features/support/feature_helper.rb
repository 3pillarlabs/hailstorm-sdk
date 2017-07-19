require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.push(File.expand_path('../../lib', __FILE__))
ENV['HAILSTORM_ENV'] = 'cucumber'
require 'hailstorm/application'
