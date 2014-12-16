require 'workers/hailstorm_setup'

puts "hailstorm project setup started"

HailstormSetup.perform_async("testproject8","/home/ravish/hailstorm_projects")

puts "hailstorm project setup ended"