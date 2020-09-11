# frozen_string_literal: true

if ENV['HAILSTORM_COVERAGE']
  SimpleCov.start do
    add_filter '/build/'
    add_filter '/spec/'
  end
end
