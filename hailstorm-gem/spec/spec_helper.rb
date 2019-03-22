# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
require 'simplecov'
require 'hailstorm/initializer/eager_load'
require 'hailstorm/initializer'
require 'hailstorm/support/configuration'
require 'active_record/base'
require 'test_schema'

$CLASSPATH << File.dirname(__FILE__)
ENV['HAILSTORM_ENV'] = 'test'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.prepend_before(:suite) do
    build_path = File.join(File.expand_path('../..', __FILE__), 'build')
    FileUtils.mkdir_p(build_path)
    boot_file_path = File.join(build_path, 'config', 'boot.rb')
    FileUtils.mkdir_p(File.join(build_path, Hailstorm.tmp_dir))
    middleware = Hailstorm::Initializer.create_middleware('hailstorm_spec', boot_file_path, {
      adapter: 'jdbcmysql',
      database: 'hailstorm_gem_test',
      username: 'hailstorm_dev',
      password: 'hailstorm_dev'
    }, Hailstorm::Support::Configuration.new)

    middleware.multi_threaded = false # disable threading in unit tests
  end

  config.append_after(:suite) do
    ActiveRecord::Base.clear_all_connections!
  end

  # Runs each example in a DB transaction and rolls back the changes.
  config.around(:each) do |ex|
    txn = ActiveRecord::Base.connection.begin_transaction
    ex.run
    begin
      txn.rollback if ActiveRecord::Base.connected?
    rescue ActiveRecord::ConnectionNotEstablished
      # no op
    end
  end

  config.append_after(:each) do
    Hailstorm.test_application = nil if Hailstorm.respond_to?(:test_application)
  end
end
