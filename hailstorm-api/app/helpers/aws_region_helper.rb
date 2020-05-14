# AWS Region Helper
module AwsRegionHelper

  NORTH_AMERICA = { code: 'North America', title: 'North America', regions: [] }.freeze

  EUROPE_MIDEAST_AFRICA = { code: 'Europe/Middle East/Africa', title: 'Europe/Middle East/Africa', regions: [] }.freeze

  ASIA_PACIFIC = { code: 'Asia Pacific', title: 'Asia Pacific', regions: [] }.freeze

  SOUTH_AMERICA = { code: 'South America', title: 'South America', regions: [] }.freeze

  def self.included(_klass)
    NORTH_AMERICA[:regions].push(
      { code: 'us-east-1', title: 'US East (Northern Virginia)' },
      { code: 'us-east-2', title: 'US East (Ohio)' },
      { code: 'us-west-2', title: 'US West (Oregon)' },
      { code: 'us-west-1', title: 'US West (Northern California)' },
      code: 'ca-central-1', title: 'Canada (Central)'
    )

    EUROPE_MIDEAST_AFRICA[:regions].push(
      { code: 'eu-west-1', title: 'Europe (Ireland)' },
      { code: 'eu-west-2', title: 'Europe (London)' },
      # { code: 'eu-north-1', title: 'Europe (Stockholm)' },
      code: 'eu-central-1', title: 'Europe (Frankfurt)',
      # { code: 'eu-west-3', title: 'Europe (Paris)' },
      # { code: 'me-south-1', title: 'Middle East (Bahrain)' },
    )

    ASIA_PACIFIC[:regions].push(
      { code: 'ap-southeast-1', title: 'Singapore' },
      # { code: 'ap-east-2', title: 'Beijing' },
      { code: 'ap-southeast-2', title: 'Sydney' },
      { code: 'ap-northeast-1', title: 'Tokyo' },
      { code: 'ap-northeast-2', title: 'Seoul' },
      # { code: 'ap-east-6', title: 'Mainland China (Ningxia)' },
      { code: 'ap-northeast-3', title: 'Osaka' },
      code: 'ap-south-1', title: 'Mumbai',
      # { code: 'ap-east-1', title: 'Hong Kong' },
    )

    SOUTH_AMERICA[:regions].push(
      code: 'sa-east-1', title: 'South America (São Paulo)'
    )
  end

  def aws_regions
    [NORTH_AMERICA, EUROPE_MIDEAST_AFRICA, ASIA_PACIFIC, SOUTH_AMERICA]
  end
end
