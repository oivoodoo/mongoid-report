require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }
  let(:yesterday) { Date.parse("19-12-2004") }
  let(:today) { Date.parse("20-12-2004") }
  let(:two_days_ago) { Date.parse("18-12-2004") }

  describe '.aggregate_for' do
    it 'aggregates fields by app' do
      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        attach_to Model do
          column :field1
        end
      end

      klass.create!(field1: 1)
      klass.create!(field1: 1)
      klass.create!(field1: 1)

      example = report_klass.new
      report = example.aggregate_for('report-klass', 'models')
      scoped = report.all

      rows = scoped.rows

      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(3)
    end

    it 'aggregates field by defined field of the mode' do
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

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        group_by :day, collection: Model
        column :field1, collection: Model
      end
      example = report_klass.new

      scope = example.aggregate_for('report-klass', 'models')
      scope = scope.query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
      scope = scope.query('$match' => { :field2 => 2 })
      scope = scope.yield
      scope = scope.query('$sort' => { day: -1 })

      scope = scope.all

      rows = scope.rows

      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)
    end

    it 'skips empty match in query' do
      klass.create(day: today , field1: 1 , field2: 2)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        group_by :day, collection: Model
        column :field1, collection: Model
      end
      example = report_klass.new

      scope = example.aggregate_for('report-klass', 'models')
      scope = scope.query()
      scope = scope.query({})

      scope  = scope.all

      rows = scope.rows

      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[0]['day']).to eq(today)
    end
  end

  describe '.aggregate' do
    it 'aggregates all defined groups in the report class' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        attach_to Model, as: 'example1' do
          group_by :day
          column :field1
        end

        attach_to Model, as: 'example2' do
          group_by :day
          column :field2
        end
      end

      example = report_klass.new
      scope = example.aggregate
      scope
        .query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
        .yield
        .query('$sort' => { day: -1 })
      scope = scope.all

      rows = scope['report-klass']['example1'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)

      rows = scope['report-klass']['example2'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field2']).to eq(4)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field2']).to eq(2)
      expect(rows[1]['day']).to eq(yesterday)
    end

    it 'should still aggregate with combined report' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        report 'example' do
          attach_to Model, as: 'model1' do
            group_by :day
            column :field1
          end

          attach_to Model, as: 'model2' do
            group_by :day
            column :field2
          end
        end
      end
      example = report_klass.new

      scope = example.aggregate
      scope
        .query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
        .yield
        .query('$sort' => { day: -1 })
      scope = scope.all

      rows = scope['example']['model1'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)

      rows = scope['example']['model2'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field2']).to eq(4)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field2']).to eq(2)
      expect(rows[1]['day']).to eq(yesterday)
    end

    it 'should still aggregate with combined report and project using the new names' do
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: today        , field1: 1 , field2: 2)
      klass.create(day: yesterday    , field1: 1 , field2: 2)
      klass.create(day: two_days_ago , field1: 1 , field2: 2)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        report 'example' do
          attach_to Model, as: 'model1' do
            group_by :day
            column :field1
          end

          attach_to Model, as: 'model2' do
            group_by :day
            column :field2
          end
        end
      end
      example = report_klass.new

      scope = example.aggregate
      scope
        .query('$match' => { :day  => { '$gte' => yesterday.mongoize, '$lte' => today.mongoize } })
        .yield
        .query('$sort' => { day: -1 })
      scope = scope.all

      rows = scope['example']['model1'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(2)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field1']).to eq(1)
      expect(rows[1]['day']).to eq(yesterday)

      rows = scope['example']['model2'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field2']).to eq(4)
      expect(rows[0]['day']).to eq(today)
      expect(rows[1]['field2']).to eq(2)
      expect(rows[1]['day']).to eq(yesterday)
    end
  end

  describe '.filter' do
    it 'creates filter' do
      klass.create(field1: 1, field2: 2)
      klass.create(field1: 3, field2: 4)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        filter field2: 2, collection: Model
        column :field1, collection: Model
      end
      example = report_klass.new

      scope = example.aggregate
      scope = scope.all

      rows = scope['report-klass']['models'].rows
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
    end

    it 'creates filter in report scope' do
      klass.create(field1: 1, field2: 2)
      klass.create(field1: 3, field2: 4)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        report 'example' do
          attach_to Model do
            filter field2: 2
            column :field1
          end
        end
      end

      example = report_klass.new
      scope = example.aggregate
      scope = scope.all

      rows = scope['example']['models'].rows
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
    end

    it 'creates filter in report scope' do
      klass.create(day: today     , field1: 1 , field2: 2)
      klass.create(day: yesterday , field1: 1 , field2: 2)
      klass.create(day: today     , field1: 3 , field2: 4)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        report 'example' do
          attach_to Model do
            filter field2: 2,
              day: ->(context) { Date.parse("20-12-2004").mongoize }
            column :field1
          end
        end
      end
      example = report_klass.new

      scope = example.aggregate
      scope = scope.all

      rows = scope['example']['models'].rows
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(1)
    end

    it 'creates filter in report scope' do
      klass.create(day: today     , field1: 1 , field2: 2)
      klass.create(day: today     , field1: 1 , field2: 2)
      klass.create(day: yesterday , field1: 1 , field2: 2)
      klass.create(day: today     , field1: 3 , field2: 4)

      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        def values
          [1, 2]
        end

        report 'example' do
          attach_to Model do
            group_by :day
            filter field2: ->(context) { { '$in' => context.values } }
            column :field1
          end
        end
      end
      example = report_klass.new

      scope = example.aggregate
      scope = scope.all

      rows = scope['example']['models'].rows
      expect(rows.size).to eq(2)
      expect(rows[0]['field1']).to eq(1)
      expect(rows[1]['field1']).to eq(2)
    end
  end

end
