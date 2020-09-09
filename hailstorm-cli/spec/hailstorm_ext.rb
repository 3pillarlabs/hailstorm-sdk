# frozen_string_literal: true

# Extensions for specs
module Hailstorm
  def self.test_application=(new_test_app)
    @test_application = new_test_app
  end

  def self.test_application
    @test_application
  end
end
