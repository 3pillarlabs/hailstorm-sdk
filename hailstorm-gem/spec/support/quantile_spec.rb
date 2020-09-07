# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/quantile'

describe Hailstorm::Support::Quantile do
  it 'should calculate quantile' do
    q = Hailstorm::Support::Quantile.new
    q.push(*1..10)
    expect(q.quantile(90)).to be == 9
  end

  context 'for #samples > 1000' do
    it 'should calculate quantile based on histogram approach' do
      q = Hailstorm::Support::Quantile.new
      q.push(*2500.times.map { rand(1000) })
      expect(q.quantile(75)).to be > 0
    end
  end
end
