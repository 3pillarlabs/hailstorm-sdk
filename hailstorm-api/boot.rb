# frozen_string_literal: true

if $PROGRAM_NAME == __FILE__
  $LOAD_PATH.unshift(__dir__)
  $LOAD_PATH.unshift(File.expand_path('../app', __FILE__))
end

require 'app'
Sinatra::Application.run! if $PROGRAM_NAME == __FILE__
