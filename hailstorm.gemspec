# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hailstorm/version"

Gem::Specification.new do |gem|
  gem.name        = "hailstorm"
  gem.version     = Hailstorm::VERSION
  gem.platform    = Gem::Platform::CURRENT
  gem.authors     = ["3PG Labs"]
  gem.email       = %w{tsg@brickred.com}
  gem.homepage    = "http://confluence.brickred.com/confluence/display/Performance/Performance+Application+User+Guide"
  gem.summary     = %q{A cloud-aware library and embedded application for distributed load testing using JMeter and optional server monitoring}
  gem.description = %q{Hailstorm uses JMeter to generate load on the system under test. You create your JMeter test plans/scripts using JMeter GUI interface and place the plans and the data files in a specific application directory. Hailstorm provides a console(shell) interface where you can configure your test environment, start tests, stop tests and generate reports. Behind the scenes, Hailstorm uses Amazon EC2 to create load agents. Each load agent is pre-installed with JMeter. The application executes your test plans in non-GUI mode using these load agents.

Hailstorm can monitor server side resources,though at the moment, the server side monitoring is limited to UNIX hosts.

Hailstorm works in an offline mode by default, which means you can exit the application and leave your tests running.}

  gem.rubyforge_project = "hailstorm"

  gem.license = "Three Pillar Global (All Rights Reserved)"

  gem.files         = `svn ls -R`.split("\n")
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/\b})
  gem.executables   = gem.files.grep(%r{^bin/\b}).map{ |f| File.basename(f) }
  gem.require_paths = %w(lib)

  # dependencies
  gem.add_dependency(%q<i18n>, [">= 0.6.0"])
  gem.add_dependency(%q<activerecord>, [">= 3.2.1"])
  gem.add_dependency(%q<actionpack>, [">= 3.2.1"])
  gem.add_dependency(%q<activerecord-jdbc-adapter>, [">= 1.2.2"])
  gem.add_dependency(%q<jruby-openssl>, ">= 0.7.6.1")
  gem.add_dependency(%q<net-ssh>, ">= 2.3.0")
  gem.add_dependency(%q<net-sftp>, ">= 2.0.5")
  gem.add_dependency(%q<nokogiri>, ">= 1.5.0")
  gem.add_dependency(%q<aws-sdk>, ">= 1.3.7")
  gem.add_dependency(%q<rubyzip>, ">= 0.9.6.1")
  gem.add_dependency(%q<terminal-table>, ">= 1.4.5")
  gem.add_dependency(%q<bundler>, ">= 1.0.22")

end
