require 'spec_helper'

describe Mongoid::Report do
  it 'works fine on multiple requests' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          match field2: 2
          column :field1
        end
      end
    end

    Model.create(field1: 1, field2: 1)
    Model.create(field1: 1, field2: 2)

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models').all
    queries1 = report.report_module_settings['example'][:reports]['models'][:queries].deep_dup

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models').all
    queries2 = report.report_module_settings['example'][:reports]['models'][:queries].deep_dup

    expect(queries1).to eq(queries2)
  end

  it 'works find on multiple requests with drops of their stats' do
    day1 = Date.parse("2014-01-01")
    1.times { Model.create(day: day1, field1: 1, field2: 1) }

    day2 = Date.parse("2014-01-02")
    2.times { Model.create(day: day2, field1: 1, field2: 2) }

    day3 = Date.parse("2014-01-03")
    3.times { Model.create(day: day3, field1: 1, field2: 3) }

    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :day
          column :field1, :field2
        end
      end
    end

    # pregenerate the data
    report = report_klass.new
    scoped = report
      .aggregate_for('example', 'models')
      .query(
        '$match' => {
          'day' => {
            '$gte' => day1.mongoize,
            '$lte' => day3.mongoize,
          },
        })
      .yield
      .out('new-models', drop: {
        'day' => {
          '$gte' => day1.mongoize,
          '$lte' => day3.mongoize,
        },
      })
      .all
    report = report_klass.new
    # read the data from output collection
    scoped = report
      .aggregate_for('example', 'models')
      .in('new-models')
      .all

    expect(scoped.rows.size).to eq(3)
    row = scoped.rows.find { |row| row['day'] == day1 }
    expect(row['field1']).to eq(1)
    expect(row['field2']).to eq(1)
    row = scoped.rows.find { |row| row['day'] == day2 }
    expect(row['field1']).to eq(2)
    expect(row['field2']).to eq(4)
    row = scoped.rows.find { |row| row['day'] == day3 }
    expect(row['field1']).to eq(3)
    expect(row['field2']).to eq(9)

    Model.where(day: day1).set(field1: 1, field2: 2)
    Model.where(day: day2).set(field1: 2, field2: 3)
    Model.where(day: day3).set(field1: 1, field2: 2)

    # pregenerate the data
    report = report_klass.new
    scoped = report
      .aggregate_for('example', 'models')
      .query(
        '$match' => {
          'day' => {
            '$gte' => day1.mongoize,
            '$lte' => day3.mongoize,
          },
        })
      .yield
      .out('new-models', drop: {
        'day' => {
          '$gte' => day1.mongoize,
          '$lte' => day3.mongoize,
        },
      })
      .all
    # read the data from output collection
    report = report_klass.new
    scoped = report
      .aggregate_for('example', 'models')
      .in('new-models')
      .all

    expect(scoped.rows.size).to eq(3)
    row = scoped.rows.find { |row| row['day'] == day1 }
    expect(row['field1']).to eq(1)
    expect(row['field2']).to eq(2)
    row = scoped.rows.find { |row| row['day'] == day2 }
    expect(row['field1']).to eq(4)
    expect(row['field2']).to eq(6)
    row = scoped.rows.find { |row| row['day'] == day3 }
    expect(row['field1']).to eq(3)
    expect(row['field2']).to eq(6)
  end
end
