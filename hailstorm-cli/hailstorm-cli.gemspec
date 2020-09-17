# frozen_string_literal: true

require 'bundler/rubygems_ext'
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'hailstorm/cli/version'

Gem::Specification.new do |gem|
  gem.name        = 'hailstorm-cli'
  gem.version     = Hailstorm::Cli::VERSION
  gem.platform    = Gem::Platform::JAVA
  gem.authors     = ['Sayantam Dey']
  gem.email       = %w[sayantam.dey@3pillarglobal.com]
  gem.homepage    = 'https://3pillarlabs.github.io/hailstorm-sdk/'
  gem.summary     = 'CLI for hailstorm - a cloud-aware library and embedded application for distributed load testing
using JMeter and optional server monitoring'
  gem.description = 'Hailstorm uses JMeter to generate load on the system under test. You create your JMeter test
plans/scripts using JMeter GUI interface and place the plans and the data files in a specific application directory.
Hailstorm CLI provides a console(shell) interface where you can configure your test environment, start tests, stop tests
and generate reports.'

  gem.rubyforge_project = 'hailstorm-cli'

  gem.license = 'MIT'

  gem.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  included_globs = %w[bin features lib templates].collect { |e| %W[#{e}/**/* #{e}/**/.*] }.flatten
  included_files = %w[Gemfile Gemfile.lock hailstorm-cli.gemspec Rakefile README.md]
  excluded_files = %w[.gitignore features/data/keys.yml]
  gem.files      = Dir.glob(included_globs).select { |f| File.file?(f) } + included_files - excluded_files

  gem.executables   = gem.files.grep(%r{^bin/\b}).map { |f| File.basename(f) }
  gem.require_paths = %w[lib]

  gem.add_runtime_dependency('hailstorm', '= 5.0.10')
end
