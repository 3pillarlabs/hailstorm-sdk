require 'sinatra'

get '/aws_regions' do
  JSON.dump({
    regions: [
      {
        code: 'North America',
        title: 'North America',
        regions: [
          {code: 'us-east-1', title: 'US East (Northern Virginia)'},
          {code: 'us-east-2', title: 'US East (Ohio)'},
          {code: 'us-west-2', title: 'US West (Oregon)'},
          {code: 'us-west-1', title: 'US West (Northern California)'},
          {code: 'ca-central-1', title: 'Canada (Central)'}
        ]
      },
      {
        code: 'Europe/Middle East/Africa',
        title: 'Europe/Middle East/Africa',
        regions: [
          {code: 'eu-west-1', title: 'Europe (Ireland)'},
          {code: 'eu-west-2', title: 'Europe (London)'},
          # { code: 'eu-north-1', title: 'Europe (Stockholm)' },
          {code: 'eu-central-1', title: 'Europe (Frankfurt)'},
          # { code: 'eu-west-3', title: 'Europe (Paris)' },
          # { code: 'me-south-1', title: 'Middle East (Bahrain)' },
        ]
      },
      {
        code: 'Asia Pacific',
        title: 'Asia Pacific',
        regions: [
          {code: 'ap-southeast-1', title: 'Singapore'},
          # { code: 'ap-east-2', title: 'Beijing' },
          {code: 'ap-southeast-2', title: 'Sydney'},
          {code: 'ap-northeast-1', title: 'Tokyo'},
          {code: 'ap-northeast-2', title: 'Seoul'},
          # { code: 'ap-east-6', title: 'Mainland China (Ningxia)' },
          {code: 'ap-northeast-3', title: 'Osaka'},
          {code: 'ap-south-1', title: 'Mumbai'},
          # { code: 'ap-east-1', title: 'Hong Kong' },
        ]
      },
      {
        code: 'South America',
        title: 'South America',
        regions: [
          {code: 'sa-east-1', title: 'South America (São Paulo)'}
        ]
      },
    ],
    defaultRegion: {code: 'us-east-1', title: 'US East (Northern Virginia)'}
  })
end
