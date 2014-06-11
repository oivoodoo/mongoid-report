require 'spec_helper'

describe Mongoid::Report do
  describe '.aggregate_for' do
    let(:klass) { Model }
    let(:yesterday) { Date.parse("19-12-2004") }
    let(:today) { Date.parse("20-12-2004") }

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

    let(:two_days_ago) { Date.parse("18-12-2004") }

    it 'wraps group query by extra match queries' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 3)

      example = Report3.new
      rows = example.aggregate_for(Model) do |queries|
        # adding extra queries before the main
        queries.unshift({ '$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } } })
        queries.unshift({ '$match' => { :field2 => 2 } })
        # adding sort to the end of aggregation query
        queries.concat([{ '$sort' => { day: -1 } }])
        queries
      end

      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)
    end
  end
end
