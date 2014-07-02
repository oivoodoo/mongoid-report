require 'spec_helper'

describe Mongoid::Report::QueriesBuilder do

  describe '.queries' do
    it 'builds queries for aggregation' do
      Report = Class.new do
        include Mongoid::Report
        column :field1, for: Model
      end
      report = Report.new

      queries = report.queries(Model)
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
      Report = Class.new do
        include Mongoid::Report

        attach_to Model do
          group_by :day
          column :field1
        end
      end
      report = Report.new

      queries = report.queries(Model)
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

    class Report5
      include Mongoid::Report

      attach_to Model do
        group_by :day, :field2

        column :field1, :field3
      end
    end

    it 'builds queries using custom one group' do
      queries = Report5.new.queries(Model)
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

end
