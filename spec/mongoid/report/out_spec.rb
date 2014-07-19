require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }

  it 'should merge properly results on splitted requests' do
    Report = Class.new do
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

    report = Report.new

    scoped = report.aggregate_for('example-models')
    scoped = scoped
      .in_batches(day: (5.days.ago.to_date..0.days.from_now.to_date))
      .out('stored-report')
      .all

    values = scoped.rows.map {|row| row['field2']}
    expect(values).to have(3).items

    StoredReport = Class.new do
      include Mongoid::Document

      store_in collection: 'stored-report'
    end

    out = StoredReport.all

  end
end
