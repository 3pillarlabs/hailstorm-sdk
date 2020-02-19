module ApiHelper

  # @param [Hash] input
  # @return [Hash]
  def deep_camelize_keys(input)
    input.deep_transform_keys do |key|
      begin
        key.to_s.camelize(:lower)
      rescue
        key
      end
    end
  end

  # @param [Object] obj
  # @return [String]
  def deep_encode(obj)
    Base64.encode64(Marshal.dump(obj))
  end

  # @param [Sting] serz
  # @return [Object]
  def deep_decode(serz)
    Marshal.load(Base64.decode64(serz))
  end
end
