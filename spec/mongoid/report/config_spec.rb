require 'spec_helper'

describe Mongoid::Report::Config do
  it 'allows to set aggregation threads' do
    expect(Mongoid::Report::Config.use_threads_on_aggregate).to eq(false)
    Mongoid::Report::Config.use_threads_on_aggregate = true
    expect(Mongoid::Report::Config.use_threads_on_aggregate).to eq(true)
  end
end
