if __FILE__ == $0
  $:.unshift(File.expand_path(File.dirname(__FILE__ )))
  $:.unshift(File.expand_path('../app', __FILE__))
end

require 'app'
Sinatra::Application.run! if __FILE__ == $0
