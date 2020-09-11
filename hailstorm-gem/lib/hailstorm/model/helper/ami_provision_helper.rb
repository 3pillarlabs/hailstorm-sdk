# frozen_string_literal: true

require 'hailstorm/model/helper'
require 'hailstorm/behavior/loggable'
require 'hailstorm/support/jmeter_installer'
require 'hailstorm/support/java_installer'

# Helper methods for installers in AMIs
class Hailstorm::Model::Helper::AmiProvisionHelper
  include Hailstorm::Behavior::Loggable

  attr_reader :region, :download_url, :user_home, :jmeter_version

  def initialize(region:, user_home:, jmeter_version:, download_url: nil)
    @region = region
    @download_url = download_url
    @user_home = user_home
    @jmeter_version = jmeter_version
  end

  # install JMeter to self.user_home
  # @param [Net::SSH::Connection::Session] ssh
  def install_jmeter(ssh)
    logger.info { "Installing JMeter for #{self.region} AMI..." }
    installer = Hailstorm::Support::JmeterInstaller.create
                                                   .with(:download_url, self.download_url)
                                                   .with(:user_home, self.user_home)
                                                   .with(:jmeter_version, self.jmeter_version)

    installer.install do |instr|
      ssh.exec!(instr)
    end
  end

  # install JAVA
  # @param [Net::SSH::Connection::Session] ssh
  def install_java(ssh)
    logger.info { "Installing Java for #{self.region} AMI..." }
    output = +''
    Hailstorm::Support::JavaInstaller.create.install do |instr|
      on_data = lambda do |data|
        output << data
        logger.debug { data }
      end
      instr_success = ssh_channel_exec_instr(ssh, instr, on_data)
      raise(Hailstorm::JavaInstallationException.new(self.region, output)) unless instr_success
    end

    verify_java(ssh)
    output
  end

  private

  # Executes the instruction on an SSH channel
  # @param ssh [Net::SSH::Connection::Session] open ssh session
  # @param instr [String] instruction to execute
  # @param on_data [Proc] handler for data on stdout
  # @param on_error [Proc] handler for data on stderr
  # @return [Boolean] true if the instruction succeeded, false otherwise
  def ssh_channel_exec_instr(ssh, instr, on_data, on_error = nil)
    instr_success = false
    channel = ssh.open_channel do |chnl|
      chnl.exec(instr) do |ch, success|
        instr_success = success
        ch.on_data { |_c, data| on_data.call(data) }
        ch.on_extended_data { |_c, _t, data| (on_error || on_data).call(data) }
      end
    end
    channel.wait
    instr_success
  end

  # Verifies Java is installed
  # @param ssh [Net::SSH::Connection::Session] open ssh session
  def verify_java(ssh)
    cmd_out = +''
    success = ssh_channel_exec_instr(ssh, 'java -version', ->(data) { cmd_out << data })
    logger.debug { cmd_out }
    raise(Hailstorm::JavaInstallationException.new(self.region, cmd_out)) unless success && cmd_out =~ /version/
  end
end
