# frozen_string_literal: true

# Helper for all APIs
module ApiHelper

  # @param [Hash] input
  # @return [Hash]
  def deep_camelize_keys(input)
    input.deep_transform_keys { |key| key.to_s.camelize(:lower) }
  end

  # @param [Object] obj
  # @return [String]
  def deep_encode(obj)
    Base64.encode64(Marshal.dump(obj))
  end

  # @param [String] serz
  # @return [Object]
  def deep_decode(serz)
    Marshal.load(Base64.decode64(serz)) # rubocop:disable Security/MarshalLoad
  end
end
