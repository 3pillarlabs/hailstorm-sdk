require 'ostruct'

include CliStepHelper

Given(/^I have [hH]ailstorm installed$/) do
  $LOAD_PATH.unshift(File.expand_path('../../../../hailstorm-gem/lib', __FILE__))
  $LOAD_PATH.unshift(File.expand_path('../../../lib', __FILE__))
  require 'hailstorm/initializer'
end

When(/^I created? (a new|the) project "([^"]*)"$/) do |new_str, project_name|
  project_path = File.join(tmp_path, project_name)
  FileUtils.rmtree(project_path) if new_str =~ /new/
  unless File.exists?(project_path)
    gems = [
        OpenStruct.new(name: 'hailstorm', path: File.expand_path('../../../../hailstorm-gem', __FILE__)),
        OpenStruct.new(name: 'hailstorm-cli', path: File.expand_path('../../..', __FILE__)),
    ]

    Hailstorm::Initializer.create_project!(tmp_path, project_name, false, gems)
  end
end

Then(/^the project structure for "([^"]*)" (?:should be|is) created$/) do |top_folder|
  project_path = File.join(tmp_path, top_folder)
  expect(File).to exist(project_path)
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.db_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.app_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.log_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.tmp_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.reports_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.config_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.vendor_dir))
  expect(File).to be_a_directory(File.join(project_path, Hailstorm.script_dir))
  expect(File).to be_a_directory(project_path)
  expect(File).to be_a_directory(project_path)
  expect(File).to exist(File.join(project_path, 'Gemfile'))
  expect(File).to exist(File.join(project_path, Hailstorm.script_dir, 'hailstorm'))
  expect(File).to exist(File.join(project_path, Hailstorm.config_dir, 'environment.rb'))
  expect(File).to exist(File.join(project_path, Hailstorm.config_dir, 'database.properties'))
  expect(File).to exist(File.join(project_path, Hailstorm.config_dir, 'boot.rb'))
end

When(/^I launch the hailstorm console within "([^"]*)" project$/) do |project_name|
  require 'pty'
  @master, slave = PTY.open
  read, @write = IO.pipe
  @pid = spawn(File.join(tmp_path, project_name, Hailstorm.script_dir, 'hailstorm'), in: read, out: slave)
  sleep 10
  read.close
  slave.close
  puts @master.read_nonblock(4096)
end

Then(/^the application should (be ready to accept|execute) commands?(?:|\s+"([^"]*)")$/) do |exec, command|
  if exec =~ /execute/
    @write.puts command
    sleep 3
    response = @master.read_nonblock(4096)
    puts response
    expect(response).to_not be_blank
    @write.puts 'exit'
    sleep 3
    @write.close
    @master.close
    Process.wait(@pid)
  end
end

When(/^I type command '(.+?)'(| and exit)$/) do |command, exit|
  @write.puts command
  sleep 3
end

Then(/^the application should show the response and exit$/) do
  response = @master.read_nonblock(4096)
  puts response
  expect(response).to_not be_blank
  @write.puts 'exit'
  sleep 3
  @write.close
  @master.close
  Process.wait(@pid)
end
