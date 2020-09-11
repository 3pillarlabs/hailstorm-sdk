# frozen_string_literal: true

require 'hailstorm/support'

# Quartile uses a histogram approach to calculate quartiles with a fast algorithm
# without resorting to sorting.
# @author Sayantam Dey
class Hailstorm::Support::Quantile
  attr_reader :histogram

  def initialize
    @histogram = []
    @samples_count = 0
  end

  def push(*elements)
    elements.each do |e|
      element = e.to_i
      if histogram[element].nil?
        histogram[element] = 1
      else
        histogram[element] += 1
      end
      @samples_count += 1
    end
  end

  def quantile(at)
    quantile_value = 0
    if @samples_count <= 1000
      samples = []
      histogram.each_with_index do |freq, value|
        freq&.times { samples.push(value) }
      end
      samples.sort!
      quantile_index = ((samples.length * at) / 100) - 1
      quantile_index = 0 if quantile_index.negative?
      quantile_value = samples[quantile_index]
    else
      sum = 0
      index = 0
      sum_max = (@samples_count * at) / 100
      while sum <= sum_max
        sum += (histogram[index] || 0)
        index += 1
      end
      quantile_value = index
    end

    quantile_value
  end
end
