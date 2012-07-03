module Hailstorm

  module Wrappable
    attr_accessor :cause
  end
  # Subclass or use this for recoverable unexpected conditions or expected error
  # conditions in workflow
  class Exception < StandardError
    include Wrappable
  end

  # Subclass or use for unrecoverable unexpected conditions
  class Error < StandardError
    include Wrappable
  end


end
