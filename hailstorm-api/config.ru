$LOAD_PATH.unshift(__dir__)
$LOAD_PATH.unshift(File.expand_path('../app', __FILE__))
require 'boot'
run Sinatra::Application
