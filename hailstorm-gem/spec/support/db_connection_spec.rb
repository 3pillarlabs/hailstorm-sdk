require 'spec_helper'
require 'hailstorm/support/db_connection'

describe Hailstorm::Support::DbConnection do
  before(:each) do
    @connection = Hailstorm::Support::DbConnection.new({})
    ActiveRecord::Base.stub!(:establish_connection)
  end

  context 'when database does not exist' do
    it 'should create a database' do
      @connection.stub!(:test_connection!).and_raise(ActiveRecord::ActiveRecordError)
      ActiveRecord::Base.should_receive(:establish_connection)
      mock_connection = double('Active Record Connection')
      mock_connection.should_receive(:create_database)
      ActiveRecord::Base.stub!(:connection).and_return(mock_connection)
      @connection.establish
    end
  end

  context 'when database already exists' do
    it 'should not create a database' do
      @connection.stub!(:test_connection!)
      @connection.should_not_receive(:create_database)
      @connection.establish
    end
  end
end
