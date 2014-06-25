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

      example = Report3.new
      rows = example.aggregate_for(klass)
      rows = rows.all

      expect(rows.count).to eq(2)
      expect(rows.summary[:field1]).to eq(3)
      expect(rows.summary['field1']).to eq(3)
    end

    it 'should support dynamic columns as well' do
      Report = Class.new do
        include Mongoid::Report

        report 'example' do
          attach_to Model do
            aggregation_field :field1
            column 'new-field1' => ->(row) { row['field1'] * 10 }
          end
        end
      end

      klass.create!(field1: 1)
      klass.create!(field1: 1)
      klass.create!(field1: 1)

      example = Report.new
      rows = example.aggregate_for('example-models')
      rows = rows.all

      expect(rows[0]['field1']).to eq(3)
      expect(rows[0]['new-field1']).to eq(30)
    end
  end

end
