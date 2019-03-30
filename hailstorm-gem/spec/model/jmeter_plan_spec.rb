require 'spec_helper'
require 'hailstorm/model/project'
require 'hailstorm/model/jmeter_plan'

describe Hailstorm::Model::JmeterPlan do
  JMX_FILE_NAME = 'hailstorm-site-basic'
  SOURCE_JMX_PATH = File.expand_path("../../../features/data/#{JMX_FILE_NAME}.jmx", __FILE__)

  before(:all) do
    dest_dir_path = File.join(Hailstorm.root, Hailstorm.app_dir)
    FileUtils.mkdir_p(dest_dir_path)
    FileUtils.cp(SOURCE_JMX_PATH, dest_dir_path)
  end

  before(:each) do
    @jmeter_plan = Hailstorm::Model::JmeterPlan.new
    class << @jmeter_plan
      attr_writer :properties_map
    end
    @jmeter_plan.test_plan_name = JMX_FILE_NAME
    @jmeter_plan.validate_plan = true
    @jmeter_plan.active = true

    @file_helper = mock(@jmeter_plan.send(:file_helper).class)
    @jmeter_plan.instance_variable_set('@file_helper', @file_helper)
  end

  context '#validate_plan' do
    context 'when all properties in plan are defined in the model properties' do
      it 'should be valid' do
        @jmeter_plan.properties_map = { NumUsers: 10, Duration: 180, ServerName: 'foo.com', RampUp: 0, StartupDelay: 0 }.stringify_keys
        expect(@jmeter_plan).to be_valid
      end
    end

    context 'when any property in plan is not defined in the model properties' do
      it 'should not be valid' do
        @jmeter_plan.properties_map = { Duration: 180, ServerName: 'foo.com', RampUp: 0, StartupDelay: 0 }.stringify_keys
        expect(@jmeter_plan).to_not be_valid
      end
    end

    context 'when a property with default value in plan is not defined in the model properties' do
      it 'should be valid' do
        @jmeter_plan.properties_map = { NumUsers: 10, Duration: 180, ServerName: 'foo.com' }.stringify_keys
        expect(@jmeter_plan).to be_valid
      end
    end
    
    context 'when JMeter plan does not have simple data writer' do
      it 'should not be valid' do
        @jmeter_plan.stub!(:extracted_property_names).and_return([])
        @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse('<foo></foo>'))
        expect(@jmeter_plan).to_not be_valid
      end
    end
  end

  context 'when property with default value is defined in model properties as well' do
    it 'the value from model properties takes precedence' do
      @jmeter_plan.properties_map = { NumUsers: 10, Duration: 180, ServerName: 'foo.com', RampUp: 10 }.stringify_keys
      @jmeter_plan.send(:extracted_property_names)
      expect(@jmeter_plan.properties_map['RampUp']).to eq(10)
    end
  end

  context '.setup' do
    before(:each) do
      @project = Hailstorm::Model::Project.create!(project_code: __FILE__)
      Hailstorm::Model::JmeterPlan
        .any_instance
        .stub(:test_plan_file_path)
        .and_return(SOURCE_JMX_PATH)
    end
    it 'should disable load agents of existing plans' do
      Hailstorm.application.config.jmeter do |jmeter|
        jmeter.properties do |property|
          property['NumUsers'] = 10
          property['Duration'] = 60
        end
      end
      jmx_files = %w[a.jmx b.jmx]
      @file_helper.stub!(:dir_glob_enumerator).and_return(jmx_files.each)
      Hailstorm::Model::JmeterPlan.setup(@project, @file_helper)
      jmx_files.pop
      @file_helper.stub!(:dir_glob_enumerator).and_return(jmx_files.each)
      @project.reload
      Hailstorm::Model::JmeterPlan.setup(@project, @file_helper)
      expect(Hailstorm::Model::JmeterPlan.where(test_plan_name: 'a').first).to be_active
      expect(Hailstorm::Model::JmeterPlan.where(test_plan_name: 'b').first).to_not be_active
    end
    context 'test_plans not specified in configuration' do
      context 'test_plans present in app_dir' do
        it 'should save all test_plans in app_dir' do
          Hailstorm.application.config.jmeter do |jmeter|
            jmeter.properties do |property|
              property['NumUsers'] = 10
              property['Duration'] = 60
            end
          end
          jmx_files = %w[a.jmx b.jmx]
          @file_helper.stub!(:dir_glob_enumerator).and_return(jmx_files.each)
          saved_plans = Hailstorm::Model::JmeterPlan.setup(@project, @file_helper)
          expect(saved_plans.size).to be == jmx_files.size
        end
      end
      context 'no test_plans in app_dir' do
        it 'should raise error' do
          Hailstorm.application.config.jmeter.test_plans = nil
          @file_helper.stub!(:dir_glob_enumerator).and_return([].each)
          expect {
            Hailstorm::Model::JmeterPlan.setup(@project, @file_helper)
          }.to raise_error(Hailstorm::Exception)
        end
      end
    end
    context 'test_plans specified in configuration' do
      context 'all specified plans exist' do
        it 'should save specified test_plans in app_dir' do
          jmx_files = %w[a.jmx b.jmx]
          Hailstorm.application.config.jmeter do |jmeter|
            jmeter.test_plans = jmx_files
            jmeter.properties do |property|
              property['NumUsers'] = 10
              property['Duration'] = 60
            end
          end
          @file_helper.stub!(:file?).and_return(true)
          saved_plans = Hailstorm::Model::JmeterPlan.setup(@project, @file_helper)
          expect(saved_plans.size).to be == jmx_files.size
        end
      end
      context 'any plan does not exist' do
        it 'should raise error' do
          Hailstorm.application.config.jmeter do |jmeter|
            jmeter.test_plans = %w[a.jmx b.jmx]
          end
          @file_helper.stub!(:file?) do |arg|
            arg.to_s == 'a.jmx' ? true : false
          end
          expect {
            Hailstorm::Model::JmeterPlan.setup(@project, @file_helper)
          }.to raise_error(Hailstorm::Exception)
        end
      end
    end
  end

  context '#content_modified?' do
    context 'new instance' do
      it 'should be true' do
        expect(@jmeter_plan).to be_content_modified
      end
    end
    context 'saved instance' do
      it 'should be false' do
        @jmeter_plan.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
        @jmeter_plan.properties = { NumUsers: 10, Duration: 60 }.to_json
        @jmeter_plan.save!
        expect(@jmeter_plan).to_not be_content_modified
      end
    end
    context 'modified plan in saved instance' do
      it 'should be true' do
        @jmeter_plan.content_hash = 'A'
        expect(@jmeter_plan).to be_content_modified
      end
    end
  end

  context '#slave_command' do
    it 'should add the properties to the command' do
      clusterable = mock(Hailstorm::Behavior::Clusterable)
      clusterable.stub!(:required_load_agent_count).and_return(10)
      @jmeter_plan.properties = { NumUsers: 5, Duration: 600 }.to_json
      command = @jmeter_plan.slave_command('192.168.0.102', clusterable)
      expect(command).to match_regex(/NumUsers=/)
      expect(command).to match_regex(/Duration=/)
    end
  end

  context '#master_command' do
    before(:each) do
      @jmeter_plan.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
      @jmeter_plan.properties = { NumUsers: 900, Duration: 600 }.to_json
      @jmeter_plan.save!
      @jmeter_plan.project.stub!(:current_execution_cycle).and_return(mock(Hailstorm::Model::ExecutionCycle, id: 10))
      @clusterable = mock(Hailstorm::Behavior::Clusterable)
      @clusterable.stub!(:required_load_agent_count).and_return(3)
    end
    context 'without slave agents' do
      it 'should add the properties to the command' do
        command = @jmeter_plan.master_command('192.168.0.100',
                                              nil,
                                              @clusterable)
        expect(command).to match_regex(/NumUsers=/)
        expect(command).to match_regex(/Duration=/)
      end
    end
    context 'with slave agents' do
      it 'should add the slave and master addresses' do
        command = @jmeter_plan.master_command('192.168.0.100',
                                              %w[192.168.0.101 192.168.0.102],
                                              @clusterable)
        expect(command).to match_regex(/192\.168\.0\.100/)
        expect(command).to match_regex(/192\.168\.0\.101/)
        expect(command).to match_regex(/192\.168\.0\.102/)
      end
    end
  end

  context '#remote_directory_hierarchy' do
    it 'should have the log key' do
      @file_helper.stub!(:local_app_directories).and_return({app: nil}.stringify_keys)
      structure = @jmeter_plan.remote_directory_hierarchy
      value = structure.values.first
      expect(value).to include('app')
      expect(value).to include('log')
    end
  end

  context '#test_artifacts' do
    it 'should skip hidden and backup files' do
      @file_helper.stub!(:file?).and_return(true)
      @file_helper.stub!(:dir_glob_enumerator).and_return(%w[
                                                          /home/foo/app/baz.jmx
                                                          /home/foo/app/baz.jmx~
                                                          /home/foo/app/.bar.jmx
                                                          ])
      artifacts = @jmeter_plan.test_artifacts
      expect(artifacts).to include('/home/foo/app/baz.jmx')
      expect(artifacts).to_not include('/home/foo/app/baz.jmx~')
      expect(artifacts).to_not include('/home/foo/app/.bar.jmx')
    end
  end

  context '#loop_forever?' do
    it 'should be true when LoopController is true' do
      xml = <<-XML
      <foo>
        <bar>
          <boolProp name="LoopController.continue_forever">true</boolProp>
        </bar>
      </foo>
      XML
      @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
      expect(@jmeter_plan.loop_forever?).to be_true
    end
    it 'should be false when LoopController is false' do
      xml = <<-XML
      <foo>
        <bar>
          <boolProp name="LoopController.continue_forever">false</boolProp>
        </bar>
      </foo>
      XML
      @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
      expect(@jmeter_plan.loop_forever?).to be_false
    end
    it 'should be false when LoopController is absent' do
      xml = <<-XML
      <foo>
      </foo>
      XML
      @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
      expect(@jmeter_plan.loop_forever?).to be_false
    end
  end

  context '#plan_name' do
    context 'name in JMeter plan is empty' do
      it 'should be same as test_plan_name' do
        xml = <<-XML
        <test>
          <TestPlan></TestPlan>
        </test>
        XML
        @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
        expect(@jmeter_plan.plan_name).to be == @jmeter_plan.test_plan_name
      end
    end
    context 'name in JMeter plan is == "Test Plan"' do
      it 'should be same as test_plan_name' do
        xml = <<-XML
        <test>
          <TestPlan testname="Test Plan"></TestPlan>
        </test>
        XML
        @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
        expect(@jmeter_plan.plan_name).to be == @jmeter_plan.test_plan_name
      end
    end
    it 'should be same as name in JMeter plan' do
      xml = <<-XML
      <test>
        <TestPlan testname="custom_name"></TestPlan>
      </test>
      XML
      @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
      expect(@jmeter_plan.plan_name).to be == 'custom_name'
    end
  end

  context '#plan_description' do
    it 'should be same as test plan comments' do
      xml = <<-XML
      <test>
        <TestPlan enabled="true">
          <stringProp name="TestPlan.comments">Description</stringProp>
        </TestPlan>
      </test>
      XML
      @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
      expect(@jmeter_plan.plan_description).to be == 'Description'
    end
  end

  context '#scenario_definitions' do
    it 'should be extracted from JMeter plan' do
      xml = <<-XML
      <hashTree>
        <ThreadGroup testname="Thread Group 1" enabled="true">
          <stringProp name="TestPlan.comments">Description for Thread Group 1</stringProp>
        </ThreadGroup>
        <hashTree>
          <hashTree>
            <HTTPSamplerProxy testclass="HTTPSamplerProxy" testname="HTTP Request 1" enabled="true">
            </HTTPSamplerProxy>
            <hashTree/>
          </hashTree>
        </hashTree>
        <ThreadGroup testname="Thread Group Disabled" enabled="false">
          <stringProp name="TestPlan.comments">Description for Thread Group 1</stringProp>
        </ThreadGroup>
        <hashTree>
          <hashTree>
            <HTTPSamplerProxy testclass="HTTPSamplerProxy" testname="HTTP Request 3" enabled="true">
            </HTTPSamplerProxy>
            <hashTree/>
          </hashTree>
        </hashTree>
        <ThreadGroup testname="Thread Group 2" enabled="true">
        </ThreadGroup>
        <hashTree>
          <hashTree>
            <HTTPSamplerProxy testclass="HTTPSamplerProxy" testname="HTTP Request 2" enabled="true">
              <stringProp name="TestPlan.comments">Description for HTTP Request 2</stringProp>
            </HTTPSamplerProxy>
            <hashTree/>
          </hashTree>
        </hashTree>
      </hashTree>
      XML
      @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
      scenarios = @jmeter_plan.scenario_definitions
      expect(scenarios.size).to be == 2
      expect(scenarios[0].thread_group).to be == 'Thread Group 1: Description for Thread Group 1'
      expect(scenarios[0].samplers).to eq(['HTTP Request 1'])
      expect(scenarios[1].thread_group).to be == 'Thread Group 2'
      expect(scenarios[1].samplers).to eq(['HTTP Request 2: Description for HTTP Request 2'])
    end
  end

  context '#num_threads' do
    context 'multiple thread groups' do
      before(:each) do
        @jmeter_plan.stub!(:threadgroups_threads_count_properties).and_return(%w[admin writer reader])
        @jmeter_props = { admin: 10, writer: 30, reader: 60 }
        @jmeter_plan.properties = @jmeter_props.to_json
      end
      context 'serial order execution' do
        it 'should return maximum number of threads' do
          @jmeter_plan.stub!(:serialize_threadgroups?).and_return(true)
          expect(@jmeter_plan.num_threads).to be == @jmeter_props[:reader]
        end
      end
      context 'parallel order execution' do
        it 'should return sum of number of threads' do
          @jmeter_plan.stub!(:serialize_threadgroups?).and_return(false)
          expect(@jmeter_plan.num_threads).to be == @jmeter_props.values.sum
        end
      end
    end
  end

  context '#serialize_threadgroups?' do
    context 'when content is not true or false' do
      it 'should load from property' do
        xml = <<-XML
        <jmeterTestPlan>
          <hashTree>
            <boolProp name="TestPlan.serialize_threadgroups">${__P(a)}</boolProp>
          </hashTree>
        </jmeterTestPlan>
        XML
        @jmeter_plan.stub!(:jmeter_document).and_yield(Nokogiri::XML.parse(xml))
        @jmeter_plan.properties = { a: true }.to_json
        @jmeter_plan.should_receive(:extract_property_name).with('${__P(a)}').and_return('a')
        expect(@jmeter_plan.send(:serialize_threadgroups?)).to be_true
      end
    end
  end
end
