require 'spec_helper'
require 'benchmark'

describe Mongoid::Report do
  let(:klass) { Model }

  it 'aggregates fields by app in threads' do
    Report = Class.new do
      include Mongoid::Report

      attach_to Model, as: 'field1-aggregation' do
        column :field1
      end

      attach_to Model, as: 'field2-aggregation' do
        column :field2
      end
    end

    30000.times { klass.create!(field1: 1, field2: 1) }

    report = Report.new
    scoped = report.aggregate

    Mongoid::Report::Config.use_threads_on_aggregate = true
    time1 = Benchmark.measure do
      rows = scoped.all
    end

    Mongoid::Report::Config.use_threads_on_aggregate = false
    time2 = Benchmark.measure do
      rows = scoped.all
    end

    puts time2
    puts time1

    time2.real.should > time1.real
  end
end
