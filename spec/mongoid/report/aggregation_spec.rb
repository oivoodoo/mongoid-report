require 'spec_helper'

describe Mongoid::Report do
  describe '.aggregate_for' do
    let(:klass) { Model }
    let(:today) { Date.parse("19-12-2004") }
    let(:yesterday) { Date.parse("20-12-2004") }

    it 'aggregates fields by default group _id as well' do
      instance1 = klass.create!(day: today, field1: 1)
      instance2 = klass.create!(day: today, field1: 1)
      instance3 = klass.create!(day: yesterday, field1: 1)

      example = Report2.new
      rows = example.aggregate_for(klass)

      expect(rows.size).to eq(3)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[2]['field1']).to eq(1)
    end

    it 'aggregates field by defined field of the mode' do
      klass.create!(day: today, field1: 1)
      klass.create!(day: today, field1: 1)
      klass.create!(day: yesterday, field1: 1)

      example = Report3.new
      rows = example.aggregate_for(klass)

      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[0]['day']).to eq(yesterday)
      expect(rows[1]['field1']).to eq(2)
      expect(rows[1]['day']).to eq(today)
    end
  end
end
