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
        %w[| / - \\].each { |v| STDOUT.write "\r#{v}"; sleep 0.3 } until @launched
        STDOUT.write "\r"
      end
    end
  end
end
