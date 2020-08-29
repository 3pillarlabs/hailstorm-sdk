require 'spec_helper'
require 'api/aws_ec2_pricing_options'

describe 'api/aws_ec2_pricing_options' do
  RAW_DATA =<<-RAW
  {
    "metadata": {
    },
    "prices": [
      {
        "id": "VDEFC4X4WEBZM9RA.JRTCKXETXF.6YS6EN2CT7",
        "unit": "Hrs",
        "price": {
          "USD": "1.7280000000"
        },
        "attributes": {
          "aws:ec2:capacitystatus": "Used",
          "aws:ec2:clockSpeed": "3.0 GHz",
          "aws:ec2:currentGeneration": "Yes",
          "aws:ec2:dedicatedEbsThroughput": "4500 Mbps",
          "aws:ec2:ecu": "139",
          "aws:ec2:enhancedNetworkingSupported": "Yes",
          "aws:ec2:instanceFamily": "General purpose",
          "aws:ec2:instanceType": "t3a.small",
          "aws:ec2:licenseModel": "No License required",
          "aws:ec2:memory": "72 GiB",
          "aws:ec2:networkPerformance": "10 Gigabit",
          "aws:ec2:normalizationSizeFactor": "72",
          "aws:ec2:operatingSystem": "Linux",
          "aws:ec2:operation": "RunInstances",
          "aws:ec2:physicalProcessor": "Intel Xeon Platinum 8124M",
          "aws:ec2:preInstalledSw": "NA",
          "aws:ec2:processorArchitecture": "64-bit",
          "aws:ec2:processorFeatures": "Intel AVX; Intel AVX2; Intel AVX512; Intel Turbo",
          "aws:ec2:storage": "1 x 900 NVMe SSD",
          "aws:ec2:tenancy": "Shared",
          "aws:ec2:term": "on-demand",
          "aws:ec2:usagetype": "BoxUsage:c5d.9xlarge",
          "aws:ec2:vcpu": "36",
          "aws:productFamily": "Compute Instance",
          "aws:region": "us-east-1",
          "aws:service": "ec2",
          "aws:sku": "VDEFC4X4WEBZM9RA"
        }
      }
    ]
  }
  RAW

  JSON_DATA = JSON.parse(RAW_DATA).freeze

  before(:each) do
    @browser = Rack::Test::Session.new(Sinatra::Application)
  end

  context 'GET /aws_ec2_pricing_options/:region_code' do
    context 'with no region data' do
      it 'should fetch data and create new region data' do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:is_a?).and_return(true)
        allow(response).to receive(:body).and_return(RAW_DATA)
        allow(Net::HTTP).to receive(:get_response).and_return(response)

        @browser.get('/aws_ec2_pricing_options/us-east-1')
        puts @browser.last_response.body
        expect(@browser.last_response).to be_ok
        json_data = JSON.parse(@browser.last_response.body)
        expect(json_data.size).to be == JSON_DATA['prices'].size
        %W[instanceType maxThreadsByInstance hourlyCostByInstance numInstances].each do |attr|
          expect(json_data[0].keys).to include(attr)
        end

        expect(AwsEc2Price.first).to_not be_nil
      end
    end

    context 'with outdated pricing data' do
      it 'should update the region pricing data' do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:is_a?).and_return(true)
        allow(response).to receive(:body).and_return(RAW_DATA)
        allow(Net::HTTP).to receive(:get_response).and_return(response)

        region = 'us-east-1'
        timestamp = Time.now
        AwsEc2Price.create!(region: region, raw_data: RAW_DATA, next_update: timestamp.ago(1.second))

        @browser.get("/aws_ec2_pricing_options/#{region}")
        expect(@browser.last_response).to be_ok
        json_data = JSON.parse(@browser.last_response.body)
        expect(json_data.size).to be == JSON_DATA['prices'].size
        expect(json_data[0]
                 .keys
                 .select { |k| %W[instanceType maxThreadsByInstance hourlyCostByInstance numInstances].include?(k) }
                 .size).to be == 4

        expect(AwsEc2Price.count).to be == 1
        expect(AwsEc2Price.first.next_update).to be > timestamp
      end
    end

    context 'with pricing data updated in last 3 months' do
      it 'should use the persisted data' do
        expect(Net::HTTP).to_not receive(:get_response)

        raw_data =<<-RAW
          [{"hourlyCostByInstance": 1.0, "clockSpeed": "3.0 GHz", "dedicatedEbsThroughput": "4500 Mbps",
            "instanceType": "m5a.large", "memory": "72 GiB", "networkPerformance": "10 Gigabit",
            "normalizationSizeFactor": "72", "vcpu": "36", "id": "VDEFC4X4WEBZM9RA.JRTCKXETXF.6YS6EN2CT7"
          }]
        RAW

        region = 'us-east-1'
        timestamp = Time.now
        AwsEc2Price.create!(region: region, raw_data: raw_data, next_update: timestamp.next_quarter)

        @browser.get("/aws_ec2_pricing_options/#{region}")
        expect(@browser.last_response).to be_ok
        json_data = JSON.parse(@browser.last_response.body)
        expect(json_data.size).to be == 1
        expect(json_data[0]
                 .keys
                 .select { |k| %W[instanceType maxThreadsByInstance hourlyCostByInstance numInstances].include?(k) }
                 .size).to be == 4
      end
    end
  end
end
