if ENV['HAILSTORM_COVERAGE']
  SimpleCov.start do
    add_filter '/build/'
  end
end
