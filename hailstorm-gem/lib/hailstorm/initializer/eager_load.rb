require 'ostruct'
require 'active_record'
require 'action_dispatch/http/mime_type'
require 'action_view'

require 'hailstorm/version'

ActiveRecord::Base.raise_in_transactional_callbacks = true
