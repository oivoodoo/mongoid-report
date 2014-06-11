require 'mongoid'
require 'active_support/all'

require 'rspec'
require 'database_cleaner'

Mongoid.configure do |config|
  config.connect_to('mongoid_report_test')
end

RSpec.configure do |config|
  config.after(:each) do
    Mongoid.purge!
  end

  config.backtrace_exclusion_patterns = [%r{lib\/rspec\/(core|expectations|matchers|mocks)}]
end

require_relative '../lib/mongoid/report.rb'
require_relative 'support/models.rb'

RSpec.configure do |config|
  require 'rspec/expectations'
  config.include RSpec::Matchers

  config.mock_with :rspec

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
