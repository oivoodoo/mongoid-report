require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }
  let(:yesterday) { Date.parse("19-12-2004") }
  let(:today) { Date.parse("20-12-2004") }
  let(:two_days_ago) { Date.parse("18-12-2004") }

  describe '.aggregate_for' do
    it 'aggregates fields by default group _id as well' do
      instance1 = klass.create!(day: today     , field1: 1)
      instance2 = klass.create!(day: today     , field1: 1)
      instance3 = klass.create!(day: yesterday , field1: 1)

      example = Report2.new
      rows = example.aggregate_for(klass)
      rows = rows.all

      expect(rows.size).to eq(3)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[2]['field1']).to eq(1)
    end

    it 'aggregates field by defined field of the mode' do
      klass.create!(day: today     , field1: 1)
      klass.create!(day: today     , field1: 1)
      klass.create!(day: yesterday , field1: 1)

      example = Report3.new

      rows = example.aggregate_for(klass)
      rows = rows.all

      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[0]['day']).to eq(yesterday)
      expect(rows[1]['field1']).to eq(2)
      expect(rows[1]['day']).to eq(today)
    end

    it 'wraps group query by extra match queries' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 3)

      example = Report3.new
      scope = example.aggregate_for(Model)
      scope = scope.query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
      scope = scope.query('$match' => { :field2 => 2 })
      scope = scope.yield
      scope = scope.query('$sort' => { day: -1 })

      rows  = scope.all

      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)
    end

    it 'skips empty match in query' do
      klass.create(day: today , field1: 1 , field2: 2)

      example = Report3.new
      scope = example.aggregate_for(Model)
      scope = scope.query()
      scope = scope.query({})

      rows  = scope.all

      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[0]['day']).to eq(today)
    end
  end

  class Report7
    include Mongoid::Report

    attach_to Model, as: 'example1' do
      group_by :day
      aggregation_field :field1
    end

    attach_to Model, as: 'example2' do
      group_by :day
      aggregation_field :field2
    end
  end

  describe '.aggregate' do
    it 'aggregates all defined groups in the report class' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)

      example = Report7.new
      scope = example.aggregate
      scope
        .query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
        .yield
        .query('$sort' => { day: -1 })
      scope = scope.all

      rows = scope['example1']
      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)

      rows = scope['example2']
      expect(rows.size).to eq(2)
      expect(rows[0]['field2']).to eq(4)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field2']).to eq(2)
      expect(rows[1]['day']).to eq(yesterday)
    end

    class Report8
      include Mongoid::Report

      report 'example' do
        attach_to Model, as: 'model1' do
          group_by :day
          aggregation_field :field1
        end

        attach_to Model, as: 'model2' do
          group_by :day
          aggregation_field :field2
        end
      end
    end

    it 'should still aggregate with combined report' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)

      example = Report8.new
      scope = example.aggregate
      scope
        .query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
        .yield
        .query('$sort' => { day: -1 })
      scope = scope.all

      rows = scope['example-model1']
      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)

      rows = scope['example-model2']
      expect(rows.size).to eq(2)
      expect(rows[0]['field2']).to eq(4)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field2']).to eq(2)
      expect(rows[1]['day']).to eq(yesterday)
    end

    class Report11
      include Mongoid::Report

      report 'example' do
        attach_to Model, as: 'model1' do
          group_by :day
          aggregation_field :field1, as: 'new-field1'
        end

        attach_to Model, as: 'model2' do
          group_by :day
          aggregation_field :field2
        end
      end
    end

    it 'should still aggregate with combined report and project using the new names' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)

      example = Report11.new
      scope = example.aggregate
      scope
        .query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
        .yield
        .query('$sort' => { day: -1 })
      scope = scope.all

      rows = scope['example-model1']
      expect(rows.size).to eq(2)
      expect(rows[0]['new-field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['new-field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)

      rows = scope['example-model2']
      expect(rows.size).to eq(2)
      expect(rows[0]['field2']).to eq(4)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field2']).to eq(2)
      expect(rows[1]['day']).to eq(yesterday)
    end
  end

  class Report15
    include Mongoid::Report

    filter field2: 2, for: Model
    aggregation_field :field1, for: Model
  end

  describe '.filter' do
    it 'creates filter' do
      klass.create(field1: 1, field2: 2)
      klass.create(field1: 3, field2: 4)

      example = Report15.new
      scope = example.aggregate
      scope = scope.all

      rows = scope[Model]
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
    end

    class Report16
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          filter field2: 2
          aggregation_field :field1
        end
      end
    end

    it 'creates filter in report scope' do
      klass.create(field1: 1, field2: 2)
      klass.create(field1: 3, field2: 4)

      example = Report16.new
      scope = example.aggregate
      scope = scope.all

      rows = scope['example-models']
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
    end

    class Report17
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          filter field2: 2,
                 day: -> { Date.parse("20-12-2004").mongoize }
          aggregation_field :field1
        end
      end
    end

    it 'creates filter in report scope' do
      klass.create(day: today     , field1: 1 , field2: 2)
      klass.create(day: yesterday , field1: 1 , field2: 2)
      klass.create(day: today     , field1: 3 , field2: 4)

      example = Report17.new
      scope = example.aggregate
      scope = scope.all

      rows = scope['example-models']
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
    end
  end

end
