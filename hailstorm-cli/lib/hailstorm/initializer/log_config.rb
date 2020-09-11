# frozen_string_literal: true

require 'hailstorm'

# Add config/log4j.xml if it exists
custom_log4j = File.join(Hailstorm.root, Hailstorm.config_dir, 'log4j.xml')
$CLASSPATH << File.dirname(custom_log4j) if File.exist?(custom_log4j)
java.lang.System.setProperty('hailstorm.log.dir', File.join(Hailstorm.root, Hailstorm.log_dir))
