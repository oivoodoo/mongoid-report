require 'spec_helper'

describe Mongoid::Report do

  describe '.summary' do
    let(:klass) { Model }
    let(:yesterday) { Date.parse("19-12-2004") }
    let(:today) { Date.parse("20-12-2004") }

    it 'returns summary for all rows' do
      klass.create!(day: today     , field1: 1)
      klass.create!(day: today     , field1: 1)
      klass.create!(day: yesterday , field1: 1)

      Report = Class.new do
        include Mongoid::Report
        group_by :day, for: Model
        column :field1, for: Model
      end
      example = Report.new

      report = example.aggregate_for(klass)
      report = report.all
      rows = report.rows

      expect(rows.count).to eq(2)
      expect(report.summary['field1']).to eq(3)
    end

    it 'should support dynamic columns as well' do
      Report = Class.new do
        include Mongoid::Report

        COLUMNS = {
          :'new-field1' => ->(context, row, options) { row['field1'] * 10 },
          :'new-field2' => ->(context, row, options) { row['field1'] * 20 },
        }

        report 'example' do
          attach_to Model do
            columns COLUMNS
            column :field1, 'new-field1'
          end
        end
      end

      klass.create!(field1: 1)
      klass.create!(field1: 1)
      klass.create!(field1: 1)

      report = Report.new
      report = report.aggregate_for('example-models')
      report = report.all
      rows = report.rows

      expect(rows[0].keys.size).to eq(2)
      expect(rows[0]['field1']).to eq(3)
      expect(rows[0]['new-field1']).to eq(30)

      expect(report.summary.keys.size).to eq(2)
      expect(report.summary['field1']).to eq(3)
      expect(report.summary['new-field1']).to eq(30)
    end
  end

end
