require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }

  it 'should work fine for no documents to insert' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :field1
          batches pool_size: 2
          column :field1, :field2
        end
      end
    end

    report = report_klass.new

    scoped = report.aggregate_for('example', 'models')
    scoped = scoped.out('stored-report')
    expect { scoped.all }.not_to raise_error
  end

  it 'should merge properly results on splitted requests' do
    ########## 1. Making the first report and out to the defined collection name.
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :field1
          batches pool_size: 2
          column :field1, :field2
        end
      end
    end

    klass.create!(day: 0.days.ago, field1: 1, field2: 1)
    klass.create!(day: 1.days.ago, field1: 1, field2: 1)
    klass.create!(day: 1.days.ago, field1: 2, field2: 2)
    klass.create!(day: 2.days.ago, field1: 3, field2: 3)
    klass.create!(day: 3.days.ago, field1: 1, field2: 1)
    klass.create!(day: 4.days.ago, field1: 1, field2: 1)

    report = report_klass.new

    scoped = report.aggregate_for('example', 'models')
    scoped = scoped
      .in_batches(day: (5.days.ago.to_date..0.days.from_now.to_date))
      .out('stored-report')
      .all

    values = scoped.rows.map {|row| row['field2']}
    expect(values.size).to eq(3)
    expect(values).to include(4)
    expect(values).to include(2)
    expect(values).to include(3)

    stored_report_klass = Class.new do
      include Mongoid::Document
      store_in collection: 'stored-report'
    end

    out = stored_report_klass.all
    expect(out.count).to eq(3)
    values = out.map { |o| o['field2'] }
    expect(values).to include(4)
    expect(values).to include(2)
    expect(values).to include(3)

    ########## 2. Making the second report and out to the defined collection name with new data.
    klass.create!(day: 3.days.ago, field1: 1, field2: 1)

    scoped = report.aggregate_for('example', 'models')
    scoped = scoped
      .in_batches(day: (5.days.ago.to_date..0.days.from_now.to_date))
      .out('stored-report')
      .all

    values = scoped.rows.map {|row| row['field2']}
    expect(values.size).to eq(3)
    expect(values).to include(5)
    expect(values).to include(2)
    expect(values).to include(3)

    out = stored_report_klass.all
    expect(out.count).to eq(3)
    values = out.map { |o| o['field2'] }
    expect(values).to include(5)
    expect(values).to include(2)
    expect(values).to include(3)
  end

  it 'should leave data out of date range' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :day
          batches pool_size: 2
          column :field1, :day
        end
      end
    end

    stored_report_klass = Class.new do
      include Mongoid::Document
      store_in collection: 'stored-report'
    end

    klass.create!(day: 0.days.ago, field1: 1)
    klass.create!(day: 1.days.ago, field1: 1)
    klass.create!(day: 1.days.ago, field1: 1)
    klass.create!(day: 2.days.ago, field1: 1)
    klass.create!(day: 3.days.ago, field1: 1)
    klass.create!(day: 4.days.ago, field1: 1)

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models')
    scoped = scoped
      .in_batches(day: (1.days.ago.to_date..0.days.from_now.to_date))
      .out('stored-report', drop: { 'day' => { '$gte' => 1.days.ago.to_date.mongoize, '$lte' => 0.days.from_now.to_date.mongoize } })
      .all

    scoped = report.aggregate_for('example', 'models')
    scoped = scoped
      .in_batches(day: (5.days.ago.to_date..1.days.ago.to_date))
      .out('stored-report', drop: { 'day' => { '$gte' => 5.days.ago.to_date.mongoize, '$lte' => 1.days.ago.to_date.mongoize } })
      .all

    out = stored_report_klass.all
    expect(out.count).to eq(5)

    days = stored_report_klass.distinct('day')
    4.times do |i|
      expect(days).to include(i.days.ago.to_date)
    end
  end
end
