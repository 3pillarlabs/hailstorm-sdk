require 'spec_helper'
require 'active_record/base'
require 'active_record/errors'
require 'logger'
require 'hailstorm/support/schema'
require 'hailstorm/middleware/application'
require 'hailstorm/support/configuration'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

describe Hailstorm::Middleware::Application do
  before(:each) do
   @app = Hailstorm::Middleware::Application.new
  end
  context '#check_database' do
    it 'should create a database if it does not exist' do
      ActiveRecord::Base.stub!(:clear_all_connections!)
      ops_ite = [ActiveRecord::ActiveRecordError, nil].each
      Hailstorm::Support::Schema.stub!(:create_schema) do
        op = ops_ite.next
        logger.debug(op.inspect)
        op ? raise(op) : op
      end
      @app.should_receive(:create_database)
      @app.stub!(:connection_spec).and_return({
         adapter: 'jdbcmysql',
         database: 'hailstorm_gem_test',
         host: 'localhost',
         port: 3306,
         username: 'hailstorm_dev',
         password: 'hailstorm_dev' })

      @app.check_database
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
end
