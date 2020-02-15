$:.unshift(File.expand_path(File.dirname(__FILE__ )))
$:.unshift(File.expand_path('../app', __FILE__))
require 'boot'
run Sinatra::Application
