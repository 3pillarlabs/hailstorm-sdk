require 'sidekiq'

class HailstormProcess
  include Sidekiq::Worker

end