require 'rubygems'
require 'bundler/setup'
require 'simplecov'
require 'hailstorm/application'

$LOAD_PATH.push(File.expand_path('../../lib', __FILE__))
$CLASSPATH << File.expand_path('../../data', __FILE__)
ENV['HAILSTORM_ENV'] = 'cucumber'
