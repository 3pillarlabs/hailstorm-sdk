require 'net/http'

Given(/^'(.+?)' is up and accessible in AWS region '(.+?)'$/) do |instance_tagged_name, region|
  site_instance = tagged_instance(instance_tagged_name, region)
  expect(site_instance).to_not be_nil
  res = Net::HTTP.get_response(URI("http://#{site_instance.public_dns_name}"))
  expect(res).to be_kind_of(Net::HTTPSuccess)
  write_site_server_url(site_instance.public_dns_name)
end


Given(/^'Hailstorm Site' is up and accessible at an IP address$/) do
  site_ip = File.read(local_site_ip_path)
  expect(site_ip).to_not be_nil
  res = Net::HTTP.get_response(URI("http://#{site_ip}"))
  expect(res).to be_kind_of(Net::HTTPSuccess)
  write_site_server_url(site_ip)
end