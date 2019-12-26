require 'sinatra'

get '/aws_ec2_pricing_options/:region_code' do |_region_code|
  sleep 0.5
  JSON.dump([
      { instanceType: "m5a.large", maxThreadsByInstance: 500, hourlyCostByInstance: 0.096, numInstances: 1 },
      { instanceType: "m5a.xlarge", maxThreadsByInstance: 1000, hourlyCostByInstance: 0.192, numInstances: 1 },
      { instanceType: "m5a.2xlarge", maxThreadsByInstance: 2000, hourlyCostByInstance: 0.3440, numInstances: 1 },
      { instanceType: "m5a.4xlarge", maxThreadsByInstance: 5000, hourlyCostByInstance: 0.6880, numInstances: 1 },
      { instanceType: "m5a.8xlarge", maxThreadsByInstance: 10000, hourlyCostByInstance: 1.3760, numInstances: 1 },
      { instanceType: "m5a.12xlarge", maxThreadsByInstance: 15000, hourlyCostByInstance: 2.0640, numInstances: 1 },
      { instanceType: "m5a.16xlarge", maxThreadsByInstance: 20000, hourlyCostByInstance: 2.7520, numInstances: 1 },
      { instanceType: "m5a.24xlarge", maxThreadsByInstance: 30000, hourlyCostByInstance: 4.1280, numInstances: 1 }
  ])
end