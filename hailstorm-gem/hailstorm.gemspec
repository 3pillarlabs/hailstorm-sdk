# -*- encoding: utf-8 -*-
require 'bundler/rubygems_ext'
$:.push File.expand_path('../lib', __FILE__)
require 'hailstorm/version'

Gem::Specification.new do |gem|
  gem.name        = 'hailstorm'
  gem.version     = Hailstorm::VERSION
  gem.platform    = Gem::Platform::JAVA
  gem.authors     = ['3Pillar Global']
  gem.email       = %w{labs@3pillarglobal.com}
  gem.homepage    = 'http://labs.3pillarglobal.com/hailstorm'
  gem.summary     = %q{A cloud-aware library and embedded application for distributed load testing using JMeter and optional server monitoring}
  gem.description = %q{Hailstorm uses JMeter to generate load on the system under test. You create your JMeter test
plans/scripts using JMeter GUI interface and place the plans and the data files in a specific application directory.
Hailstorm provides a console(shell) interface where you can configure your test environment, start tests, stop tests
and generate reports. Behind the scenes, Hailstorm uses Amazon EC2 to create load agents. Each load agent is
pre-installed with JMeter. The application executes your test plans in non-GUI mode using these load agents.

Hailstorm can monitor server side resources,though at the moment, the server side monitoring is limited to UNIX hosts.

Hailstorm works in an offline mode by default, which means you can exit the application and leave your tests running.}

  gem.rubyforge_project = 'hailstorm'

  gem.license = 'MIT'

  excluded_files   = ['Gemfile.lock', '.gitignore']
  gem.files         = `git ls-files`.split("\n") - excluded_files
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/\b})
  gem.executables   = gem.files.grep(%r{^bin/\b}).map{ |f| File.basename(f) }
  gem.require_paths = %w(lib)

  # dependencies
  gem.add_dependency(%q<i18n>, ['= 0.6.11'])
  gem.add_dependency(%q<activerecord>, ['= 4.1.6'])
  gem.add_dependency(%q<actionpack>, ['= 4.1.6'])
  gem.add_dependency(%q<activerecord-jdbc-adapter>, ['= 1.3.11'])
  gem.add_dependency(%q<jruby-openssl>, '~> 0.9')
  gem.add_dependency(%q<net-ssh>, '~> 4.2')
  gem.add_dependency(%q<net-sftp>, '= 2.1.2')
  gem.add_dependency(%q<nokogiri>, '~> 1.6.3.1')
  gem.add_dependency(%q<aws-sdk>, '= 1.57.0')
  gem.add_dependency(%q<rubyzip>, '= 1.2.1')
  gem.add_dependency(%q<terminal-table>, '= 1.4.5')
  gem.add_dependency(%q<bouncy-castle-java>, '= 1.5.0146.1')
  gem.add_dependency(%q<httparty>, '= 0.13.1')
  gem.add_dependency(%q<haikunator>, '= 1.1.0')

  gem.add_development_dependency(%q<rspec>, '~> 2.13.0')
  gem.add_development_dependency(%q<cucumber>, '~> 2.4')
  gem.add_development_dependency(%q<activerecord-jdbcmysql-adapter>, ['= 1.3.11'])
  gem.add_development_dependency(%q<activerecord-jdbcsqlite3-adapter>, ['= 1.3.11'])
  gem.add_development_dependency(%q<ruby-debug>)
  gem.add_development_dependency(%q<rubocop>)
end
