# frozen_string_literal: true

# Progress indicator for terminals
module Hailstorm
  module Initializer
    # Progress indicator for CLI
    class Progressive

      def self.show_while(&_block)
        progress = self.new
        t1 = Thread.new { progress.show }
        begin
          yield
        ensure
          progress.launched = true
          t1.join
        end
      end

      attr_writer :launched

      def initialize
        @launched = false
      end

      def show
        %w[| / - \\].each do |v|
          $stdout.write "\r#{v}"
          sleep 0.3
        end until @launched
        $stdout.write "\r"
      end
    end
  end
end
