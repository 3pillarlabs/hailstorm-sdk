require 'hailstorm'
require 'fileutils'

custom_log4j = File.join(File.expand_path('../../../config', __FILE__), 'log4j.xml')
$CLASSPATH << File.dirname(custom_log4j)

log_path = File.expand_path('../../../log', __FILE__)
FileUtils.mkdir_p(log_path)
java.lang.System.setProperty('hailstorm.log.dir', log_path)
