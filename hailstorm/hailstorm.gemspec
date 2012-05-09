# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hailstorm/version"

Gem::Specification.new do |s|
  s.name        = "hailstorm"
  s.version     = Hailstorm::VERSION
  s.platform    = Gem::Platform::CURRENT
  s.authors     = ["BrickRed (TPG) TSG"]
  s.email       = ["tsg@brickred.com"]
  s.homepage    = "http://confluence.brickred.com/confluence/display/Performance/Performance+Application+User+Guide"
  s.summary     = %q{A cloud-aware library and embedded application for distributed load testing using JMeter and optional server monitoring}
  s.description = %q{Hailstorm uses JMeter to generate load on the system under test. You create your JMeter test plans/scripts using JMeter GUI interface and place the plans and the data files in a specific application directory. Hailstorm provides a console(shell) interface where you can configure your test environment, start tests, stop tests and generate reports. Behind the scenes, Hailstorm uses Amazon EC2 to create load agents. Each load agent is pre-installed with JMeter. The application executes your test plans in non-GUI mode using these load agents.

Hailstorm can monitor server side resources,though at the moment, the server side monitoring is limited to UNIX hosts.

Hailstorm works in an offline mode by default, which means you can exit the application and leave your tests running.}

  s.rubyforge_project = "hailstorm"

  # TODO: Add appropriate license
  s.license = "Proprietary BrickRed TPG"

  s.files         = `svn ls -R`.split("\n")
  s.test_files    = `svn ls -R | egrep '^(test|spec|features)/\\b'`.split("\n")
  s.executables   = `svn ls -R | egrep '^bin/\\b'`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)

  # dependencies
  s.add_dependency(%q<i18n>, [">= 0.6.0"])
  s.add_dependency(%q<activerecord>, [">= 3.2.1"])
  s.add_dependency(%q<jdbc-sqlite3>, [">= 3.7.2"])
  s.add_dependency(%q<activerecord-jdbc-adapter>, [">= 1.2.2"])
  s.add_dependency(%q<activerecord-jdbcsqlite3-adapter>, [">= 1.2.2"])
  s.add_dependency(%q<jruby-openssl>, ">= 0.7.6.1")
  s.add_dependency(%q<net-ssh>, ">= 2.3.0")
  s.add_dependency(%q<net-sftp>, ">= 2.0.5")
  s.add_dependency(%q<nokogiri>, ">= 1.5.0")
  s.add_dependency(%q<aws-sdk>, ">= 1.3.7")
  s.add_dependency(%q<erubis>, ">= 2.7.0")
  s.add_dependency(%q<rubyzip>, ">= 0.9.6.1")
  s.add_dependency(%q<terminal-table>, ">= 1.4.5")
end
