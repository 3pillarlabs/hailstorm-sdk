# set JAVA classpath
# Add all Java Jars and log4j.xml (will not be added if already added in above case) to classpath
java_lib = File.expand_path('../../java/lib', __FILE__)
$CLASSPATH << java_lib
Dir[File.join(java_lib, '*.jar')].each do |jar|
  require(jar)
end
