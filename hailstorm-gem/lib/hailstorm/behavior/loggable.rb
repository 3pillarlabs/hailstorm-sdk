require 'hailstorm/behavior'
require 'hailstorm/support/log4j_backed_logger'

# Module to inject Loggable behavior
# @author Sayantam Dey
module Hailstorm::Behavior::Loggable

  # Callback function which gets called when this module is included in a class
  # Add a static logger and an instance logger method to recipient
  def self.included(recipient)
    # add the static logger
    def recipient.logger
      Hailstorm::Support::Log4jBackedLogger.get_logger(self)
    end

    recipient.class_eval do
      def logger
        @logger || Hailstorm::Support::Log4jBackedLogger.get_logger(self.class)
      end
    end
  end
end
