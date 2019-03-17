require 'spec_helper'
require 'tempfile'
require 'hailstorm/model/client_stat'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/master_agent'

describe Hailstorm::Model::ClientStat do
  context '.collect_client_stats' do
    it 'should collect create_client_stats' do
      cluster_instance = Hailstorm::Model::AmazonCloud.new
      expect(cluster_instance).to respond_to(:master_agents)
      agent_generator = Proc.new do |jmeter_plan_id, result_file|
        agent = Hailstorm::Model::MasterAgent.new
        agent.jmeter_plan_id = jmeter_plan_id
        expect(agent).to respond_to(:result_for)
        agent.stub!(:result_for).and_return(result_file)
        agent
      end
      uniq_ids = []
      agents = [[1, 'a.jtl'], [1, 'b.jtl'], [2, 'c.jtl']].map do |id, file|
        uniq_ids.push(id) unless uniq_ids.include?(id)
        agent_generator.call(id, file)
      end
      cluster_instance.stub_chain(:master_agents, :where).and_return(agents)
      Hailstorm::Model::ClientStat.should_receive(:create_client_stat).exactly(uniq_ids.size).times
      Hailstorm::Model::ClientStat.collect_client_stats(mock(Hailstorm::Model::ExecutionCycle), cluster_instance)
    end
  end

  context '.create_client_stat' do
    before(:each) do
      @execution_cycle = Hailstorm::Model::ExecutionCycle.new
      @execution_cycle.id = 123
      @jmeter_plan = Hailstorm::Model::JmeterPlan.new
      @jmeter_plan.id = 12
      @clusterable = Hailstorm::Model::AmazonCloud.new
      Hailstorm::Model::JmeterPlan.stub!(:find).and_return(@jmeter_plan)
      Hailstorm::Model::ClientStat.stub!(:do_create_client_stat)
      Hailstorm::Model::JtlFile.stub!(:persist_file)
    end
    it 'should not combine_stats for multiple files' do
      Hailstorm::Model::ClientStat.should_not_receive(:combine_stats)
      stat_file_paths = [ Tempfile.new ]
      Hailstorm::Model::ClientStat.create_client_stat(@execution_cycle,
                                                      @jmeter_plan.id,
                                                      @clusterable,
                                                      stat_file_paths,
                                                      false)
      stat_file_paths.each { |sfp| sfp.unlink }
    end
    it 'should combine_stats for multiple files' do
      stat_file_paths = [ Tempfile.new, Tempfile.new ]
      Hailstorm::Model::ClientStat.should_receive(:combine_stats)
        .with(stat_file_paths, @execution_cycle.id, @jmeter_plan.id, @clusterable.id, false)
        .and_return(stat_file_paths.first)
      Hailstorm::Model::ClientStat.create_client_stat(@execution_cycle,
                                                      @jmeter_plan.id,
                                                      @clusterable,
                                                      stat_file_paths,
                                                      false)
      stat_file_paths.each { |sfp| sfp.unlink }
    end
    it 'should delete stat_file_paths' do
      stat_file_paths = [ Tempfile.new, Tempfile.new ]
      Hailstorm::Model::ClientStat.should_receive(:combine_stats)
        .with(stat_file_paths, @execution_cycle.id, @jmeter_plan.id, @clusterable.id, true)
        .and_return(Tempfile.new)
      Hailstorm::Model::ClientStat.create_client_stat(@execution_cycle,
                                                      @jmeter_plan.id,
                                                      @clusterable,
                                                      stat_file_paths)
      stat_file_paths.each { |sfp| sfp.unlink }
    end
  end

  context '.do_create_client_stat' do
    it 'should create a client_stat' do
      project = Hailstorm::Model::Project.create!(project_code: 'execution_cycle_spec')
      execution_cycle = Hailstorm::Model::ExecutionCycle.create!(project: project,
                                                                 status: :stopped,
                                                                 started_at: Time.now,
                                                                 stopped_at: Time.now + 15.minutes)
      jmeter_plan = Hailstorm::Model::JmeterPlan.create!(project: project,
                                                         test_plan_name: 'priming',
                                                         content_hash: 'A',
                                                         latest_threads_count: 100)
      jmeter_plan.update_column(:active, true)
      clusterable = Hailstorm::Model::AmazonCloud.create!(project: project,
                                                          access_key: 'A',
                                                          secret_key: 'A',
                                                          region: 'us-east-1')
      clusterable.update_column(:active, true)

      Hailstorm::Model::JtlFile.stub!(:persist_file)

      log_data =<<-JTL
      <?xml version="1.0" encoding="UTF-8"?>
      <testResults version="1.2">
        <sample t="14256" lt="0" ts="1354685431293" s="true" lb="Home Page" rc="200" rm="Number of samples in transaction : 3, number of failing samples : 0" tn=" Static Pages 1-1" dt="" by="33154">
          <httpSample t="13252" lt="13191" ts="1354685436312" s="true" lb="/Home.aspx" rc="200" rm="OK" tn=" Static Pages 1-1" dt="text" by="21967"/>
          <httpSample t="116" lt="63" ts="1354685454578" s="true" lb="/imagedownload.aspx" rc="200" rm="OK" tn=" Static Pages 1-1" dt="bin" by="10269">
            <httpSample t="63" lt="63" ts="1354685454578" s="true" lb="http://webshop-test.acetrax.com/imagedownload.aspx?schema=0d2fa497-d898-44d4-b97c-9d9075a5d9f0&amp;channel=F660CA13-0FE8-4F86-9B94-B8A55F7866CD&amp;content_id=21918EC0-ECC7-4397-B7EA-5BE6C2A663D7&amp;field=image_storage&amp;lang=pt&amp;ver=1&amp;filetype=png" rc="302" rm="Found" tn="" dt="text" by="1023"/>
            <httpSample t="52" lt="52" ts="1354685454642" s="true" lb="http://webshop-test.acetrax.com/img/imgsredirectstate_0d2fa497-d898-44d4-b97c-9d9075a5d9f0$$F660CA13-0FE8-4F86-9B94-B8A55F7866CD$$21918EC0-ECC7-4397-B7EA-5BE6C2A663D7$$image_storage$$pt$$1.png" rc="200" rm="OK" tn=" Static Pages 1-1" dt="bin" by="9246"/>
          </httpSample>
          <httpSample t="888" lt="887" ts="1354685459695" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-1" dt="text" by="918"/>
        </sample>
        <sample t="6301" lt="0" ts="1354685443297" s="true" lb="Home Page" rc="200" rm="Number of samples in transaction : 3, number of failing samples : 0" tn=" Static Pages 1-2" dt="" by="33154">
          <httpSample t="6108" lt="6052" ts="1354685448298" s="true" lb="/Home.aspx" rc="200" rm="OK" tn=" Static Pages 1-2" dt="text" by="21967"/>
          <httpSample t="114" lt="62" ts="1354685459408" s="true" lb="/imagedownload.aspx" rc="200" rm="OK" tn=" Static Pages 1-2" dt="bin" by="10269">
            <httpSample t="62" lt="62" ts="1354685459408" s="true" lb="http://webshop-test.acetrax.com/imagedownload.aspx?schema=0d2fa497-d898-44d4-b97c-9d9075a5d9f0&amp;channel=F660CA13-0FE8-4F86-9B94-B8A55F7866CD&amp;content_id=21918EC0-ECC7-4397-B7EA-5BE6C2A663D7&amp;field=image_storage&amp;lang=pt&amp;ver=1&amp;filetype=png" rc="302" rm="Found" tn="" dt="text" by="1023"/>
            <httpSample t="52" lt="52" ts="1354685459470" s="true" lb="http://webshop-test.acetrax.com/img/imgsredirectstate_0d2fa497-d898-44d4-b97c-9d9075a5d9f0$$F660CA13-0FE8-4F86-9B94-B8A55F7866CD$$21918EC0-ECC7-4397-B7EA-5BE6C2A663D7$$image_storage$$pt$$1.png" rc="200" rm="OK" tn=" Static Pages 1-2" dt="bin" by="9246"/>
          </httpSample>
          <httpSample t="79" lt="79" ts="1354685464523" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-2" dt="text" by="918"/>
        </sample>
        <sample t="1183" lt="0" ts="1354685455318" s="true" lb="Home Page" rc="200" rm="Number of samples in transaction : 3, number of failing samples : 0" tn=" Static Pages 1-3" dt="" by="33154">
          <httpSample t="869" lt="811" ts="1354685460318" s="true" lb="/Home.aspx" rc="200" rm="OK" tn=" Static Pages 1-3" dt="text" by="21967"/>
          <httpSample t="97" lt="62" ts="1354685466190" s="true" lb="/imagedownload.aspx" rc="200" rm="OK" tn=" Static Pages 1-3" dt="bin" by="10269">
            <httpSample t="62" lt="62" ts="1354685466190" s="true" lb="http://webshop-test.acetrax.com/imagedownload.aspx?schema=0d2fa497-d898-44d4-b97c-9d9075a5d9f0&amp;channel=F660CA13-0FE8-4F86-9B94-B8A55F7866CD&amp;content_id=21918EC0-ECC7-4397-B7EA-5BE6C2A663D7&amp;field=image_storage&amp;lang=pt&amp;ver=1&amp;filetype=png" rc="302" rm="Found" tn="" dt="text" by="1023"/>
            <httpSample t="35" lt="35" ts="1354685466252" s="true" lb="http://webshop-test.acetrax.com/img/imgsredirectstate_0d2fa497-d898-44d4-b97c-9d9075a5d9f0$$F660CA13-0FE8-4F86-9B94-B8A55F7866CD$$21918EC0-ECC7-4397-B7EA-5BE6C2A663D7$$image_storage$$pt$$1.png" rc="200" rm="OK" tn=" Static Pages 1-3" dt="bin" by="9246"/>
          </httpSample>
          <httpSample t="217" lt="217" ts="1354685471287" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-3" dt="text" by="918"/>
        </sample>
        <sample t="6091" lt="0" ts="1354685460592" s="true" lb="Login Page" rc="200" rm="Number of samples in transaction : 2, number of failing samples : 0" tn=" Static Pages 1-1" dt="" by="9594">
          <httpSample t="5935" lt="5935" ts="1354685465601" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-1" dt="text" by="8676"/>
          <httpSample t="156" lt="156" ts="1354685476537" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-1" dt="text" by="918"/>
        </sample>
        <sample t="2132" lt="0" ts="1354685464604" s="true" lb="Login Page" rc="200" rm="Number of samples in transaction : 2, number of failing samples : 0" tn=" Static Pages 1-2" dt="" by="9594">
          <httpSample t="1928" lt="1928" ts="1354685469604" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-2" dt="text" by="8676"/>
          <httpSample t="204" lt="204" ts="1354685476533" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-2" dt="text" by="918"/>
        </sample>
        <sample t="511" lt="0" ts="1354685471510" s="true" lb="Login Page" rc="200" rm="Number of samples in transaction : 2, number of failing samples : 0" tn=" Static Pages 1-3" dt="" by="9594">
          <httpSample t="265" lt="264" ts="1354685476512" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-3" dt="text" by="8676"/>
          <httpSample t="246" lt="245" ts="1354685481777" s="true" lb="/Generic.aspx" rc="200" rm="OK" tn=" Static Pages 1-3" dt="text" by="918"/>
        </sample>
      </testResults>
      JTL
      client_stat = Hailstorm::Model::ClientStat
                      .do_create_client_stat(execution_cycle, jmeter_plan, clusterable, log_data.strip_heredoc)
      expect(client_stat).to_not be_nil
    end
  end
end
