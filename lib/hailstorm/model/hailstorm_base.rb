require 'hailstorm/model'

class Hailstorm::Model::HailstormBase < ActiveRecord::Base
  self.abstract_class = true

  def self.establish_connection spec
    ActiveRecord::Base.establish_connection spec
  end
end