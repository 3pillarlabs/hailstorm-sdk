require 'sinatra'

get '/aws_regions' do
  sleep 0.5
  JSON.dump({
                regions: [
                    {
                        code: 'North America',
                        title: 'North America',
                        regions: [
                            { code: 'us-east-1', title: 'US East (Northern Virginia)' },
                            { code: 'us-east-2', title: 'US East (Ohio)' },
                            { code: 'us-west-1', title: 'US West (Oregon)' },
                            { code: 'us-west-2', title: 'US West (Northern California)' },
                            { code: 'ca-central-1', title: 'Canada (Central)' }
                        ]
                    },
                    {
                        code: 'Europe/Middle East/Africa',
                        title: 'Europe/Middle East/Africa',
                        regions: [
                            { code: 'eu-east-1', title: 'Europe (Ireland)' },
                            { code: 'eu-east-2', title: 'Europe (London)' },
                            { code: 'eu-central-2', title: 'Europe (Stockholm)' },
                            { code: 'eu-central-1', title: 'Europe (Frankfurt)' },
                            { code: 'eu-central-3', title: 'Europe (Paris)' },
                            { code: 'me-north-1', title: 'Middle East (Bahrain)' },
                        ]
                    },
                    {
                        code: 'Asia Pacific',
                        title: 'Asia Pacific',
                        regions: [
                            { code: 'ap-east-1', title: 'Singapore' },
                            { code: 'ap-east-2', title: 'Beijing' },
                            { code: 'ap-east-3', title: 'Sydney' },
                            { code: 'ap-east-4', title: 'Tokyo' },
                            { code: 'ap-east-5', title: 'Seoul' },
                            { code: 'ap-east-6', title: 'Mainland China (Ningxia)' },
                            { code: 'ap-east-7', title: 'Osaka' },
                            { code: 'ap-east-8', title: 'Mumbai' },
                            { code: 'ap-east-9', title: 'Hong Kong' },
                        ]
                    },
                    {
                        code: 'South America',
                        title: 'South America',
                        regions: [
                            { code: 'sa-sa-1', title: 'South America (São Paulo)' }
                        ]
                    },
                ],
                defaultRegion: { code: 'us-east-1', title: 'US East (Northern Virginia)' }
            })
end