module Hailstorm

  # Subclass or use this for recoverable unexpected conditions or expected error
  # conditions in workflow
  class Exception < StandardError
  end

  # Subclass or use for unrecoverable unexpected conditions
  class Error < StandardError
  end

end
