require 'hailstorm/support'

# Helper methods for processing collections available to recipient instance and class.
module Hailstorm::Support::CollectionHelper

  # All methods
  module Methods

    # Yields the single element in a collection or each element in a different thread, and waits for all
    # threads to join before the method returns.
    # @param [Array] collection
    def visit_collection(collection, &_block)
      if collection.count == 1
        yield collection.first
      else
        collection.each do |element|
          Hailstorm::Support::Thread.start(element) do |e|
            yield e
          end
        end
        Hailstorm::Support::Thread.join
      end
    end
  end

  include Methods

  def self.included(recipient)
    recipient.extend(Methods)
  end
end
