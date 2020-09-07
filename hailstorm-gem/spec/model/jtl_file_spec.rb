# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'hailstorm/model/jtl_file'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/project'

describe Hailstorm::Model::JtlFile do
  def create_client_stat
    project = Hailstorm::Model::Project.create!(project_code: 'jtl_file_spec')
    execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                               status: :stopped,
                                                               started_at: Time.new(2014, 1, 23, 12, 0, 0),
                                                               stopped_at: Time.new(2014, 1, 23, 12, 30, 0))
    jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: project,
                                                       test_plan_name: 'prime',
                                                       content_hash: 'A')
    clusterable = Hailstorm::Model::AmazonCloud.create!(project: project,
                                                        access_key: 'A',
                                                        secret_key: 'A',
                                                        region: 'us-east-1')
    Hailstorm::Model::ClientStat.create!(execution_cycle: execution_cycle,
                                         jmeter_plan: jmeter_plan,
                                         clusterable: clusterable,
                                         threads_count: 100,
                                         aggregate_ninety_percentile: 1200.5,
                                         aggregate_response_throughput: 23.45,
                                         last_sample_at: Time.new(2014, 1, 23, 12, 30, 0))
  end

  context '.persist_file' do
    it 'should break up the JTL files into multiple chunks' do
      client_stat = create_client_stat
      num_full_chunks = 3
      padding = 512
      data_size = (Hailstorm::Model::JtlFile::DATA_CHUNK_SIZE * num_full_chunks) + padding
      jtl_file_path = Tempfile.new
      File.open(jtl_file_path, 'w') do |out|
        data_size.times { out.write(rand(255)) } # write bytes at random
      end

      Hailstorm::Model::JtlFile.persist_file(client_stat, jtl_file_path)
      expect(Hailstorm::Model::JtlFile.where(client_stat_id: client_stat.id).count).to be == (num_full_chunks + 1)
    end
  end

  context '.export_file' do
    it 'should combine multiple chunks to single file' do
      bytes = 'Hello, is there anybody out there?'
      # echo $bytes | gzip -c | base64
      gz_bytes = Base64.decode64('H4sIAH2Ik1wAA/NIzcnJ11HILFYoyUgtSlVIzKtMyk+pVMgvLYGI2AMAXBii/yIAAAA=')
      mid_point = gz_bytes.length.even? ? gz_bytes.length / 2 : (gz_bytes.length + 1) / 2
      lub = mid_point - 1
      uub = gz_bytes.length - 1
      chunk1 = gz_bytes[0..lub]
      chunk2 = gz_bytes[mid_point, uub]
      client_stat = create_client_stat
      Hailstorm::Model::JtlFile.create!(client_stat: client_stat, chunk_sequence: 1, data_chunk: chunk1)
      Hailstorm::Model::JtlFile.create!(client_stat: client_stat, chunk_sequence: 2, data_chunk: chunk2)

      jtl_file_path = Tempfile.new
      Hailstorm::Model::JtlFile.export_file(client_stat, jtl_file_path)
      expect(File.read(jtl_file_path)).to be == bytes
    end
  end
end
