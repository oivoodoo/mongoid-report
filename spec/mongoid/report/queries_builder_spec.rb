require 'spec_helper'

describe Mongoid::Report::QueriesBuilder do

  describe '.queries' do
    it 'builds queries for aggregation' do
      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        column :field1, collection: Model
      end
      report = report_klass.new

      queries = report.queries('report-klass', 'models')
      expect(queries.size).to eq(3)
      expect(queries[0]).to eq(
        '$project' => {
          :_id    => 1,
          'field1' => 1,
        })
      expect(queries[1]).to eq(
        '$group' => {
          :_id    => { },
          'field1' => { '$sum'  => '$field1' },
        })
      expect(queries[2]).to eq(
        '$project' => {
          :_id    => 0,
          'field1' => '$field1',
        })
    end

    it 'builds queries using custom one group' do
      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        attach_to Model do
          group_by :day
          column :field1
        end
      end
      report = report_klass.new

      queries = report.queries('report-klass', 'models')
      expect(queries.size).to eq(3)
      expect(queries[0]).to eq(
        '$project' => {
          :_id     => 1,
          'field1' => 1,
          'day'    => 1,
        })
      expect(queries[1]).to eq(
        '$group' => {
          :_id    => { 'day' => '$day' },
          'field1' => { '$sum' => '$field1' },
        })
      expect(queries[2]).to eq(
        '$project' => {
          :_id     => 0,
          'day'    => '$_id.day',
          'field1' => '$field1',
        })
    end

    it 'builds queries using custom one group' do
      report_klass = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end

        attach_to Model do
          group_by :day, :field2
          column :field2, :field1, :field3
        end
      end

      queries = report_klass.new.queries('report-klass', 'models')
      expect(queries.size).to eq(3)
      expect(queries[0]).to eq(
        '$project' => {
          :_id     => 1,
          'field1' => 1,
          'field3' => 1,
          'day'    => 1,
          'field2' => 1,
        })
      expect(queries[1]).to eq(
        '$group' => {
          :_id    => { 'day' => '$day', 'field2' => '$field2' },
          'field1' => { '$sum' => '$field1' },
          'field3' => { '$sum' => '$field3' },
        })
      expect(queries[2]).to eq(
        '$project' => {
          :_id     => 0,
          'day'    => '$_id.day',
          'field2' => '$_id.field2',
          'field1' => '$field1',
          'field3' => '$field3',
        })
    end
  end

  it 'allows to pass raw query' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to 'models' do
          query '$match' => { 'field1' => 1 }
          match 'field2' => 2
          match 'field3' => ->(report) { 3 }
          match '$or' => ->(this) {
            [
              { 'field1' => 1 },
              { 'field2' => 2 },
            ]
          }
          column :field1, :field2
        end
      end
    end

    Model.create(field1: 1, field2: 2, field3: 1)
    Model.create(field1: 2, field2: 2, field3: 1)
    Model.create(field1: 1, field2: 2, field3: 3)

    report = report_klass.new
    queries = report.report_module_settings['example'][:reports]['models'][:queries]
    expect(queries).to include('$match' => { 'field1' => 1 })
    expect(queries).to include('$match' => { 'field2' => 2 })

    scope = report.aggregate_for('example', 'models').all
    expect(scope.rows.size).to eq(1)
    expect(scope.rows[0]['field1']).to eq(1)
    expect(scope.rows[0]['field2']).to eq(2)
  end # it

end
