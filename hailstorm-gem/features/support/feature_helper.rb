require 'rubygems'
require 'bundler/setup'
require 'simplecov'

$LOAD_PATH.push(File.expand_path('../../lib', __FILE__))
$CLASSPATH << File.expand_path('../../data', __FILE__)
ENV['HAILSTORM_ENV'] = 'cucumber'

require 'hailstorm/initializer'
require 'hailstorm/initializer/eager_load'
