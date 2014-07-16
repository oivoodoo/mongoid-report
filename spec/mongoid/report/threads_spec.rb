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

  it 'should work faster using batches in threads on aggregate' do
    Report1 = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :day
          column :field1
        end
      end
    end

    Report2 = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :day
          batches size: 5, by: :day
          column :field1
        end
      end
    end

    5.times do |i|
      10000.times { klass.create!(day: i.days.ago, field1: 1) }
    end

    time1 = Benchmark.measure do
      rows = scoped
        .in_batches(day: (0.days.ago.to_date..5.days.from_now.to_date))
        .all
    end

    time2 = Benchmark.measure do
      rows = scoped.all
    end

    puts time2
    puts time1

    time2.real.should > time1.real
  end
end
