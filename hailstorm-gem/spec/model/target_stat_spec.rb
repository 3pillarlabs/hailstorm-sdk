# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tempfile'
require 'hailstorm/model/target_stat'
require 'hailstorm/model/nmon'

describe Hailstorm::Model::TargetStat do
  context '.create_target_stat' do
    it 'should calculate averages' do
      project = Hailstorm::Model::Project.create!(project_code: 'target_stat_spec')
      allow_any_instance_of(Hailstorm::Model::Nmon).to receive(:transfer_identity_file)
      target_host = Hailstorm::Model::Nmon.create!(host_name: 'a',
                                                   project: project,
                                                   role_name: 'server',
                                                   ssh_identity: 'a',
                                                   user_name: 'ubuntu')
      target_host.update_column(:active, true)
      allow(target_host).to receive(:calculate_average_stats).and_return([25.0, 2345.5, 12.3])
      allow(target_host).to receive(:cpu_usage_trend).and_yield(StringIO.new('A' * 2048))
      allow(target_host).to receive(:memory_usage_trend).and_yield(StringIO.new('A' * 2048))
      allow(target_host).to receive(:swap_usage_trend).and_yield(StringIO.new('A' * 2048))

      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                 status: :stopped,
                                                                 started_at: Time.new(2010, 10, 8, 10, 0, 0),
                                                                 stopped_at: Time.new(2010, 10, 8, 10, 15, 0))

      target_stat = Hailstorm::Model::TargetStat.create_target_stat(execution_cycle, target_host)
      expect(target_stat).to be_persisted
    end
  end

  context '#utilization_graph' do
    it 'should build the graph' do
      project = Hailstorm::Model::Project.create!(project_code: 'target_stat_spec')
      allow_any_instance_of(Hailstorm::Model::Nmon).to receive(:transfer_identity_file)
      target_host = Hailstorm::Model::Nmon.create!(host_name: 'a',
                                                   project: project,
                                                   role_name: 'server',
                                                   ssh_identity: 'a',
                                                   user_name: 'ubuntu')
      target_host.update_column(:active, true)
      sample_generator = -> { rand(100) }
      allow(target_host).to receive(:each_cpu_usage_sample) do |&block|
        block.call(sample_generator.call)
      end
      allow(target_host).to receive(:each_memory_usage_sample) do |&block|
        block.call(sample_generator.call)
      end
      allow(target_host).to receive(:each_swap_usage_sample) do |&block|
        block.call(sample_generator.call)
      end

      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                 status: :stopped,
                                                                 started_at: Time.new(2010, 10, 8, 10, 0, 0),
                                                                 stopped_at: Time.new(2010, 10, 8, 10, 15, 0))

      allow_any_instance_of(Hailstorm::Model::TargetStat).to receive(:write_blobs)
      gz_blob = Base64.decode64('H4sIAKRrklwAA3PkAgClhW5IAgAAAA==') # <-- echo 'A' | gzip -c | base64
      target_stat = Hailstorm::Model::TargetStat.create!(execution_cycle: execution_cycle,
                                                         target_host: target_host,
                                                         average_cpu_usage: 25.0,
                                                         average_memory_usage: 2345.5,
                                                         cpu_usage_trend: gz_blob,
                                                         memory_usage_trend: gz_blob,
                                                         swap_usage_trend: gz_blob)
      grapher = spy('ResourceUtilizationGraph')
      expect(grapher).to receive(:finish)
      target_stat.utilization_graph(builder: grapher, working_path: RSpec.configuration.build_path)
    end
  end

  context Hailstorm::Model::TargetStat::GraphBuilderFactory do
    it 'should create utilization_graph builder' do
      expect(Hailstorm::Model::TargetStat::GraphBuilderFactory
               .utilization_graph(Tempfile.new.path, 5)).to_not be_nil
    end
  end
end
