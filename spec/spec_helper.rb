require 'mongoid'
require 'active_support/all'

require 'rspec'

Mongoid.configure do |config|
  config.connect_to('mongoid_report_test')
end

require_relative '../lib/mongoid/report.rb'
require_relative 'support/models.rb'

RSpec.configure do |config|
  require 'rspec/expectations'
  config.include RSpec::Matchers

  config.mock_with :rspec

  config.filter_run_excluding long: true unless ENV['ALL']

  config.after(:each) do
    Mongoid.purge!
  end

  config.backtrace_exclusion_patterns = [%r{lib\/rspec\/(core|expectations|matchers|mocks)}]
end
