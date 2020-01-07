Given(/^the "([^"]+)" command line processor is ready$/) do |app_name|
  require 'hailstorm/controller/cli'
  require 'hailstorm/middleware/command_execution_template'

  @mock_cmd_exec_template = mock(Hailstorm::Middleware::CommandExecutionTemplate)
  Hailstorm::Initializer.create_middleware(app_name, File.join(tmp_path, app_name, 'config', 'boot.rb'))
  @cli = Hailstorm::Controller::Cli.new(Hailstorm.application)
  @cli.cmd_executor.instance_variable_set('@command_execution_template', @mock_cmd_exec_template)
end

Given(/^I have a log file on the local filesystem$/) do
  expect(Dir["#{data_path}/*.jtl"].count).to be > 0
end

When(/^I import results(?: from '([^']+)'|)$/) do |paths|
  @mock_cmd_exec_template.stub!(:results).and_return(%w[a.jtl])
  if paths
    @cmd_args = paths.split(/\s*,\s*/).map { |p| File.join(data_path, p)}.join(' ')
  else
    results_import_path = File.join(tmp_path, Hailstorm.app_name, Hailstorm.results_import_dir)
    file_name = 'jmeter_log_sample.jtl'
    @cmd_args = File.join(results_import_path, file_name)
  end

  @result_args = []
  @mock_cmd_exec_template.should_receive(:results) { |*args| @result_args.push(*args) }
  if paths
    @cli.process_cmd_line("results import #{@cmd_args}")
  else
    @cli.process_cmd_line('results import')
  end
end

Given(/^I have a log file in import directory$/) do
  results_import_path = File.join(tmp_path, Hailstorm.app_name, Hailstorm.results_import_dir)
  FileUtils.rm_rf(results_import_path)
  FileUtils.mkdir_p(results_import_path)
  file_name = 'jmeter_log_sample.jtl'
  FileUtils.cp(File.join(data_path, file_name), File.join(results_import_path, file_name))
end

Then(/^the log files? should be imported$/) do
  expect(@result_args).to_not be_empty
  expect(@result_args).to eq([false, nil, :import, [[@cmd_args], nil]])
end
