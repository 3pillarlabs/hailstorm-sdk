# Extensions for specs
module Hailstorm
  @@test_application = nil

  def self.test_application=(new_test_app)
    @@test_application = new_test_app
  end

  def self.test_application
    @@test_application
  end
end
