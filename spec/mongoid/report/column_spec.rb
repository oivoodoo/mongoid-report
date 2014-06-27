require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }
  let(:yesterday) { Date.parse("19-12-2004") }
  let(:today) { Date.parse("20-12-2004") }
  let(:two_days_ago) { Date.parse("18-12-2004") }
  let(:report_klass) do
    Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          group_by :day
          aggregation_field :field1
          column 'dynamic-field1' => ->(context, row) { row['field1'] * 10 }
        end
      end
    end
  end

  it 'calculates dynamic field for each row in the report' do
    klass.create(day: today     , field1: 1)
    klass.create(day: yesterday , field1: 1)
    klass.create(day: today     , field1: 1)

    example = report_klass.new
    scope = example.aggregate
    scope = scope.all

    rows = scope['example-models']
    expect(rows.size).to eq(2)
    expect(rows[0]['field1']).to eq(1)
    expect(rows[0]['dynamic-field1']).to eq(10)
    expect(rows[1]['field1']).to eq(2)
    expect(rows[1]['dynamic-field1']).to eq(20)
  end
end
