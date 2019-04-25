require 'spec_helper'
require 'active_record/base'
require 'active_record/errors'
require 'logger'
require 'hailstorm/support/schema'
require 'hailstorm/middleware/application'
require 'hailstorm/support/configuration'
require 'hailstorm_ext'

describe Hailstorm::Middleware::Application do
  before(:each) do
   @app = Hailstorm::Middleware::Application.new
  end

  it 'should have multi_thread enabled' do
    expect(@app).to be_multi_threaded
  end

  context '#check_database' do
    before(:each) do
      ActiveRecord::Base.stub!(:clear_all_connections!)
      @app.stub!(:connection_spec).and_return(
        adapter: 'jdbcmysql',
        database: 'hailstorm_test',
        host: 'localhost',
        port: 3306,
        username: 'hailstorm_dev',
        password: 'hailstorm_dev'
      )
      @mock_connection = double('Mock Database Connection').as_null_object
      ActiveRecord::Base.stub!(:connection).and_return(@mock_connection)
    end
    context 'when database does not exist' do
      it 'should create a database' do
        @mock_connection.stub!(:exec_query).and_raise(ActiveRecord::ActiveRecordError)
        @app.should_receive(:create_database)
        @app.check_database
      end
    end
    context 'when database already exists' do
      it 'should not create a database' do
        @mock_connection.stub!(:exec_query).and_return(1)
        @app.should_not_receive(:create_database)
        @app.check_database
      end
    end
  end

  context '#config' do
    it 'should yield a config instance' do
      @app.config do |config|
        expect(config).to be_a(Hailstorm::Support::Configuration)
      end
    end
    it 'should return same config instance' do
      c1 = @app.config
      expect(c1).to be_a(Hailstorm::Support::Configuration)
      @app.config { |c2| expect(c2).to be == c1 }
    end
  end

  context '#load_config' do
    it 'should load and freeze config' do
      env_conf_path = File.join(Dir.mktmpdir, 'environment.rb')
      File.open(env_conf_path, 'w') do |env_file|
        env_file.puts <<-HERE.strip_heredoc
          Hailstorm.test_application.config do |config|
            config.jmeter do |jmeter|
              jmeter.properties do |props|
                props[:num_threads] = 1000
                props[:ramp_up] = 100
              end
              jmeter.properties(test_plan: 'burst_test.jmx') do |props|
                props[:ramp_up] = 0
              end
            end
            
            config.clusters(:amazon_cloud) do |aws|
              aws.region = 'us-east-1a'
            end
            
            config.clusters(:data_center) do |data_center|
              data_center.title = 'Digital Ocean'
            end

            config.monitors(:nmon) do |monitor|
              monitor.groups(:web) do |web_servers|
                web_servers.hosts('pikachu', 'dora', 'elephant')
              end
            end
          end
        HERE
      end
      Hailstorm.test_application = @app
      expect { @app.load_config(env_conf_path) }.to_not raise_error
      expect(@app.config.clusters.first).to respond_to(:region)
      expect(@app.config.clusters.first.region).to be == 'us-east-1a'
      expect(@app.config.clusters[1]).to respond_to(:title)
      expect(@app.config.clusters[1].title).to be == 'Digital Ocean'
      expect(@app.config).to be_frozen
    end
    context 'with error in config' do
      it 'should raise_error' do
        env_conf_path = File.join(Dir.mktmpdir, 'environment_fail.rb')
        File.open(env_conf_path, 'w') do |env_file|
          env_file.puts <<-HERE.strip_heredoc
          Hailstorm.test_application.config do |config|
            config.coffee do |coffee|
              coffee.make = true
            end
          end
          HERE
        end
        Hailstorm.test_application = @app
        expect { @app.load_config(env_conf_path) }.to raise_error
      end
    end
  end

  context '#connection_spec' do
    it 'should ignore blank properties' do
      @app.stub!(:load_db_properties).and_return(x: 1, y: ' ', z: nil)
      conn_spec = @app.send(:connection_spec)
      expect(conn_spec).to include(:x)
      expect(conn_spec).to_not include(:y)
      expect(conn_spec).to_not include(:z)
      expect(conn_spec).to eq(@app.instance_variable_get('@connection_spec'))
    end
    it 'should add :database key' do
      @app.stub!(:load_db_properties).and_return(adapter: 'mysql')
      conn_spec = @app.send(:connection_spec)
      expect(conn_spec).to include(:database)
    end
    it 'should not override :database key' do
      props = {adapter: 'mysql', database: 'hailstorm_test'}
      @app.stub!(:load_db_properties).and_return(props)
      conn_spec = @app.send(:connection_spec)
      expect(conn_spec[:database]).to be == props[:database]
    end
    it 'should provide :database if not present in spec' do
      props = {adapter: 'mysql'}
      @app.stub!(:load_db_properties).and_return(props)
      conn_spec = @app.send(:connection_spec)
      expect(conn_spec[:database]).to match(/^hailstorm_/)
    end
    context ':adapter is sqlite|derby' do
      %w[sqlite derby].each do |adapter|
        before(:each) do
          @app.stub!(:load_db_properties).and_return(adapter: adapter)
        end
        it 'should disable multi_threaded mode' do
          @app.send(:connection_spec)
          expect(@app).to_not be_multi_threaded
        end
      end
    end
    context ':adapter is not sqlite|derby' do
      it 'should add default properties' do
        @app.stub!(:load_db_properties).and_return(adapter: 'mysql')
        expect(@app.send(:connection_spec)).to include(:pool)
        expect(@app.send(:connection_spec)).to include(:wait_timeout)
      end
      it 'should be able to override default properties' do
        props = {adapter: 'mysql', pool: 100000, wait_timeout: 60.minutes}
        @app.stub!(:load_db_properties).and_return(props)
        conn_spec = @app.send(:connection_spec)
        expect(conn_spec[:pool]).to be == props[:pool]
        expect(conn_spec[:wait_timeout]).to be == props[:wait_timeout]
      end
      it 'should be able to add additional properties' do
        props = {adapter: 'mysql', host: 'data.ba.se'}
        @app.stub!(:load_db_properties).and_return(props)
        conn_spec = @app.send(:connection_spec)
        expect(conn_spec).to include(:host)
        expect(conn_spec[:host]).to be == props[:host]
      end
    end
  end

  context '#load_db_properties' do
    it 'should load properties from a file path' do
      db_props_file_path = File.join(Dir.mktmpdir, 'database.properties')
      File.open(db_props_file_path, 'w') do |file|
        file.puts <<-HERE.strip_heredoc
          # Database properties file
          adapter = jdbcmysql
          database =
          host = localhost
        HERE
      end
      props_map = @app.send(:load_db_properties, db_props_file_path)
      expect(props_map).to be == { adapter: 'jdbcmysql', database: '', host: 'localhost' }
    end
  end
end
