require 'spec_helper'
require 'hailstorm/middleware/command_execution_template'

describe Hailstorm::Middleware::CommandExecutionTemplate do

  before(:each) do
    mock_delegate = double('Mock Delegate')
    @app = Hailstorm::Middleware::CommandExecutionTemplate.new(mock_delegate)
  end

  %i[setup start stop abort terminate results].each do |cmd|
    context "##{cmd}" do
      it 'should pass through to :model_delegate' do
        @app.model_delegate.should_receive(cmd)
        @app.send(cmd)
      end
    end
  end

  context '#results' do
    it 'should return data, operation and format' do
      @app.model_delegate.stub!(:results).and_return([])
      seq = ['foo.jtl', {'jmeter' => '1', 'cluster' => '2'}]
      expect(@app.results(false, 'json', :show, seq)).to be == [[], :show, 'json']
    end

    context 'with extract_last == true' do
      before(:each) do
        r1 = { id: 3, total_threads_count: 100, avg_90_percentile: 1300.43, avg_tps: 2000.345,
               formatted_started_at: '2018-01-01 14:10:00', formatted_stopped_at: '2018-01-01 14:25:00' }
        r2 = r1.clone
        r2[:id] = 4
        @data = [ OpenStruct.new(r1), OpenStruct.new(r2) ]
        @app.model_delegate.stub!(:results).and_return(@data)
      end
      it 'should return only the last data' do
        expect(@app.results(true, nil, :show)[0]).to be == [@data.last]
      end
    end
  end

  context '#purge' do
    before(:each) do
      @mock_ex_cycle = double('Mock Execution Cycle')
      @app.model_delegate.stub!(:execution_cycles).and_return([@mock_ex_cycle])
    end
    it 'should destroy all execution_cycles' do
      @mock_ex_cycle.should_receive(:destroy)
      @app.purge
    end
    context 'tests' do
      it 'should destroy all execution_cycles' do
        @mock_ex_cycle.should_receive(:destroy)
        @app.purge('tests')
      end
    end
    context 'clusters' do
      it 'should purge_clusters' do
        @app.model_delegate.should_receive(:purge_clusters)
        @app.purge('clusters')
      end
    end
    context 'all' do
      it 'should destroy mock_delegate' do
        @app.model_delegate.should_receive(:destroy)
        @app.purge('all')
      end
    end
  end

  context '#status' do
    context 'current_execution_cycle is nil' do
      it 'should not raise_error' do
        @app.model_delegate.stub!(:current_execution_cycle).and_return(nil)
        expect { @app.status }.to_not raise_error
      end
    end
    context 'current_execution_cycle is truthy' do
      before(:each) do
        @app.model_delegate.stub!(:current_execution_cycle).and_return(true)
      end
      context 'no running agents' do
        before(:each) do
          @app.model_delegate.stub!(:check_status).and_return([])
        end
        it 'should not raise_error' do
          expect { @app.status }.to_not raise_error
        end
        context 'json format' do
          it 'should not raise_error' do
            expect { @app.status('json') }.to_not raise_error
          end
        end
      end
      context 'with running agents' do
        before(:each) do
          check_status_datum = OpenStruct.new(clusterable: OpenStruct.new(slug: 'amazon-east-1'),
                                              public_ip_address: '8.8.8.8',
                                              jmeter_pid: 9364)
          @app.model_delegate.stub!(:check_status).and_return([check_status_datum])
        end
        it 'should not raise_error' do
          expect { @app.status }.to_not raise_error
        end
        context 'json format' do
          it 'should not raise_error' do
            expect { @app.status('json') }.to_not raise_error
          end
        end
      end
    end
  end

end
