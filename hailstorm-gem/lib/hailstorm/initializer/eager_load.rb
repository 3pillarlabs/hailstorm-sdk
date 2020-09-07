# frozen_string_literal: true

require 'ostruct'

require 'active_record'
ActiveRecord::Base.default_timezone = :local

require 'action_dispatch/http/mime_type'
require 'action_view'
require 'hailstorm/version'
require 'hailstorm/model/nmon'
require 'hailstorm/initializer/file_extn'
