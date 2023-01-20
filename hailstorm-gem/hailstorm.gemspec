# frozen_string_literal: true

require 'bundler/rubygems_ext'
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'hailstorm/version'

Gem::Specification.new do |gem|
  gem.name        = 'hailstorm'
  gem.version     = Hailstorm::VERSION
  gem.platform    = Gem::Platform::JAVA
  gem.authors     = ['Sayantam Dey']
  gem.email       = ['sayantam@gmail.com']
  gem.homepage    = 'https://3pillarlabs.github.io/hailstorm-sdk/'
  gem.summary     = 'A cloud-aware library for distributed load testing using JMeter and
optional server monitoring'
  gem.description = 'Hailstorm uses JMeter to generate load on the system under test. You create your JMeter test
plans/scripts using JMeter GUI interface. Hailstorm uses these test plans to generate load. Hailstorm uses Amazon EC2
to create load agents. Each load agent is pre-installed with JMeter. The application executes your test plans in
non-GUI mode using these load agents. Hailstorm can also work with containers or virtual machines or physical machines
in your data center. Hailstorm can monitor server side resources,though at the moment, the server side monitoring is
limited to UNIX hosts.'

  gem.rubyforge_project = 'hailstorm'

  gem.license = 'MIT'

  gem.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  included_globs = %w[bin lib templates].collect { |e| %W[#{e}/**/* #{e}/**/.*] }.flatten
  included_files = %w[Gemfile Gemfile.lock hailstorm.gemspec Rakefile]
  excluded_files = %w[.gitignore lib/hailstorm/java/.project]
  gem.files         = Dir.glob(included_globs).select { |f| File.file?(f) } + included_files - excluded_files
  gem.require_paths = %w[lib]

  # dependencies
  gem.add_dependency('actionpack', '>= 6.0', '< 7.1')
  gem.add_dependency('activerecord-jdbc-adapter', '~> 60.2')
  gem.add_dependency('aws-sdk-ec2', '~> 1')
  gem.add_dependency('erubis', '~> 2.7.0')
  gem.add_dependency('haikunator', '~> 1.1.0')
  gem.add_dependency('net-sftp', '~> 3.0.0')
  gem.add_dependency('net-ssh', '~> 5.0.2')
  gem.add_dependency('nokogiri', '~> 1.10.9')
  gem.add_dependency('rubyzip', '~> 2.3.0')
  gem.add_dependency('terminal-table', '~> 1.6.0')
end
