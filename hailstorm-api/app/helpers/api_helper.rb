module ApiHelper

  # @param [Hash] input
  # @return [Hash]
  def deep_camelize_keys(input)
    input.deep_transform_keys do |key|
      begin
        camel = key.to_s.camelize
        "#{camel[0].downcase}#{camel[1..-1]}"
      rescue
        key
      end
    end
  end
end
