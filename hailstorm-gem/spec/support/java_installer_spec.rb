require 'spec_helper'
require 'hailstorm/support/java_installer'

describe Hailstorm::Support::JavaInstaller do
  context '#install, default implementation' do
    it 'should yield at least one instruction' do
      installer = Hailstorm::Support::JavaInstaller.create
      count = 0
      installer.install do |_instr|
        count += 1
      end
      expect(count).to be > 0
    end
  end

  context '#attributes' do
    it 'should set the instance variables' do
      installer = Hailstorm::Support::JavaInstaller.create
      attrs = { installer_type: 'binary', use_curl: true }
      installer.attributes!(attrs)
      expect(installer.instance_variable_get('@installer_type')).to eql(attrs[:installer_type])
      expect(installer.instance_variable_get('@use_curl')).to eql(attrs[:use_curl])
    end
  end

  context '.create' do
    it 'should instantiate class corresponding to symbol' do
      installer = Hailstorm::Support::JavaInstaller.create(:trusty)
      expect(installer).to be_a(Hailstorm::Support::JavaInstaller::Trusty)
    end
  end
end
