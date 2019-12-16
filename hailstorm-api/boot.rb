$:.unshift(File.expand_path(File.dirname(__FILE__ ))) if __FILE__ == $0
require 'app'
Sinatra::Application.run! if __FILE__ == $0
