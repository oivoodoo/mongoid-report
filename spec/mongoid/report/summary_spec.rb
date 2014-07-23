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

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        group_by :day, collection: Model
        column :field1, collection: Model
      end
      example = report_klass.new

      report = example.aggregate_for('report-klass', 'models')
      report = report.all
      rows = report.rows

      expect(rows.count).to eq(2)
      expect(report.summary['field1']).to eq(3)
    end

    it 'should support dynamic columns as well' do
      report_klass = Class.new do
        include Mongoid::Report

        COLUMNS = {
          :'new-field1' => ->(context, row, options) { row['field1'] * 10 },
          :'new-field2' => ->(context, row, options) { row['field2'] * 20 },
        }

        report 'example' do
          attach_to Model do
            columns COLUMNS
            column :field1, :field2, 'new-field1', 'new-field2'
          end
        end
      end

      klass.create!(field1: 1, field2: 3)
      klass.create!(field1: 2, field2: 2)
      klass.create!(field1: 3, field2: 1)

      report = report_klass.new
      report = report.aggregate_for('example', 'models')
      report = report.all
      rows = report.rows

      expect(rows[0].keys.size).to eq(4)
      expect(rows[0]['field1']).to eq(6)
      expect(rows[0]['field2']).to eq(6)
      expect(rows[0]['new-field1']).to eq(60)
      expect(rows[0]['new-field2']).to eq(120)

      expect(report.summary.keys.size).to eq(4)
      expect(report.summary['field1']).to eq(6)
      expect(report.summary['field2']).to eq(6)
      expect(report.summary['new-field1']).to eq(60)
      expect(report.summary['new-field2']).to eq(120)
    end

    it 'should not summaries day field' do
      report_klass = Class.new do
        include Mongoid::Report

        report 'example' do
          attach_to Model do
            group_by :day
            column :day, :field1
          end
        end
      end

      klass.create!(day: DateTime.now, field1: 1)
      klass.create!(day: DateTime.now, field1: 1)
      klass.create!(day: DateTime.now, field1: 1)

      report = report_klass.new
      report = report.aggregate_for('example', 'models')
      report = report.all
      rows = report.rows

      expect(rows[0].keys.size).to eq(2)
      expect(rows[0]['field1']).to eq(3)
      expect(rows[0]['day']).to be

      expect(report.summary.keys.size).to eq(1)
      expect(report.summary['field1']).to eq(3)
    end

    it 'should calculate dynamic columns for summary' do
      report_klass = Class.new do
        include Mongoid::Report

        COLUMNS = {
          :'new-field1' => ->(context, row, options) { row['field2'] * 10 / row['field1'] * 1.2 },
          :'new-field2' => ->(context, row, options) { row['field2'] * 20.0 * row['field1'] / 100 },
        }

        report 'example' do
          attach_to Model do
            columns COLUMNS
            group_by :day
            column :day, :field1, :field2, 'new-field1', 'new-field2'
          end
        end
      end

      klass.create!(day: 1.day.ago, field1: 1, field2: 3)
      klass.create!(day: 2.day.ago, field1: 2, field2: 0)
      klass.create!(day: 3.day.ago, field1: 3, field2: 1)
      klass.create!(day: 4.day.ago, field1: 4, field2: 0)

      report = report_klass.new
      report = report.aggregate_for('example', 'models')
      report = report.all
      rows = report.rows

      expect(rows[0].keys.size).to eq(5)
      expect(rows[0]['field1']).to eq(4)
      expect(rows[0]['field2']).to eq(0)
      expect(rows[0]['new-field1']).to eq(0.0)
      expect(rows[0]['new-field2']).to eq(0.0)

      expect(report.summary.keys.size).to eq(4)
      expect(report.summary['field1']).to eq(10)
      expect(report.summary['field2']).to eq(4)
      expect(report.summary['new-field1']).to eq(4.8)
      expect(report.summary['new-field2']).to eq(8.0)
    end

  end

end
