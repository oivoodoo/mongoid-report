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
          batches pool_size: 4
          column :field1
        end
      end
    end

    TIMES = 20

    TIMES.times.map do |i|
      Thread.new do
        10000.times { klass.create!(day: i.days.ago, field1: 1) }
      end
    end.map(&:join)

    report1 = Report1.new
    scoped = report1.aggregate

    time1 = Benchmark.measure do
      rows = scoped.all
      expect(rows['example-models'].rows[0]['field1']).to eq(10000)
    end

    report2 = Report2.new
    scoped = report2.aggregate_for('example-models')

    time2 = Benchmark.measure do
      scoped = scoped
        .in_batches(day: (5.days.ago.to_date..0.days.from_now.to_date))
        .all
      expect(scoped.rows[0]['field1']).to eq(10000)
    end

    puts time2
    puts time1

    time1.real.should > time2.real
  end
end
