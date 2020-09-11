# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/java_installer'

describe Hailstorm::Support::JavaInstaller do
  context Hailstorm::Support::JavaInstaller::Trusty do
    context '#install' do
      it 'should yield at least one instruction' do
        installer = Hailstorm::Support::JavaInstaller.create
        count = 0
        installer.install do |_instr|
          count += 1
        end
        expect(count).to be > 0
      end

      context 'with sudo? == true' do
        before(:each) do
          installer = Hailstorm::Support::JavaInstaller.create
          @instructions = []
          installer.install { |inst| @instructions << inst }
        end
        context 'single instruction' do
          it 'should prepend sudo to instruction' do
            expect(@instructions[2]).to start_with('sudo')
          end
        end
        context 'piped instructions' do
          it 'should prepend sudo to every piped instruction' do
            piped_commands = @instructions[0].split(/\|/).collect(&:strip)
            piped_commands.each { |pc| expect(pc).to start_with('sudo') }
          end
        end
      end
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

  context Hailstorm::Support::JavaInstaller::AbstractInstaller do
    before(:each) do
      @empty_installer = Object.new.extend(Hailstorm::Support::JavaInstaller::AbstractInstaller)
    end

    it 'should have empty instructions' do
      expect(@empty_installer.instructions).to be_empty
    end

    it 'should not need sudo privilege' do
      expect(@empty_installer).to_not be_sudo
    end
  end
end
