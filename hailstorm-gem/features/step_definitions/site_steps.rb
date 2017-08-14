Given(/^'(.+?)' is up and accessible in AWS region '(.+?)'$/) do |instance_tagged_name, region|
  site_instance = tagged_instance(instance_tagged_name, region)
  expect(site_instance).to_not be_nil
  write_site_server_url(site_instance.public_dns_name)
end
