require 'spec_helper'
require 'hailstorm/support/waiter'

describe Hailstorm::Support::Waiter do

  before(:each) do
    @component = Object.new
    @component.extend(Hailstorm::Support::Waiter)
  end

  context '#wait_for' do
    context 'Operation times out' do
      it 'should raise error' do
        expect {
          @component.wait_for('Mock drill to fail',
                              timeout_sec: 0.3,
                              sleep_duration: 0.1,
                              err_attrs: { region: 'us-east-1' }) { false }
        }.to raise_error(Hailstorm::Exception)
      end
    end

    context 'Operation completes within time' do
      it 'should return result of operation' do
        expect(@component.wait_for('Mock drill to succeed',
                                   timeout_sec: 1,
                                   sleep_duration: 0.3) { __FILE__ }).to eql(__FILE__)
      end
    end
  end
end
