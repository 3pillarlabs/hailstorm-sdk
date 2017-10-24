if ENV['HAILSTORM_COVERAGE']
  SimpleCov.start do
    root File.expand_path(__FILE__)
  end
end
