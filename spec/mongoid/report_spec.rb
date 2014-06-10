require 'spec_helper'

describe Mongoid::Report do

  class Model
    include Mongoid::Document

    field :field1, type: Integer, default: 0
    field :field2, type: Integer, default: 0
    field :field3, type: Integer, default: 0

    field :day,    type: DateTime
  end

  class Report1
    require 'pry'
    binding.pry

    include Mongoid::Report

    aggregation_field :field1, for: Model
  end

  describe '.aggregation_field' do
    it 'defines field for aggregation using class method' do
      example = Report1.new
      expect(example).to be_respond_to(:field1)
    end

    it 'defines as reader only' do
      example = Report1.new
      expect{ example.field1 = 'value' }.to raise_error
    end

    it 'defines field with 0 by default' do
      example = Report1.new
      expect(example.field1).to eq(0)
    end

    it 'defines aggegration settings' do
      expect(Report1).to be_respond_to(:settings)
    end

    it 'defines aggregation field for specific model to make queries' do
      fields = Report1.fields(Model)
      expect(fields).to have(1).item
      expect(fields).to include(:field1)
    end
  end

  class Report2
    include Mongoid::Report

    attach_to Model do
      aggregation_field :field1
    end
  end

  describe '.attach_to' do
    it 'defines method in report class to attach report to the model' do
      expect { Report2.new }.to be
      expect(Report2).to be_respond_to(:attach_to)
    end

    it 'defines field in terms of attached model' do
      fields = Report2.fields(Model)
      expect(fields).to have(1).item
      expect(fields).to include(:field1)
    end
  end

  class Report3
    include Mongoid::Report

    group_by :day, for: Model

    aggregation_field :field1, for: Model
  end

  class Report4
    include Mongoid::Report

    attach_to Model do
      group_by :day

      aggregation_field :field1
    end
  end

  describe '.group_by' do
    it 'defines group by method as class method' do
      expect(Report3).to be_respond_to(:group_by)
    end

    it 'stores group by settings under report class' do
      group_by_settings = Report3.settings[Model][:group_by]
      expect(group_by_settings).to eq([:day])
    end

    it 'defines groups in terms of attached model' do
      groups = Report4.groups(Model)
      expect(groups).to have(1).item
      expect(groups).to include(:day)
    end
  end

  describe '.queries' do
    it 'builds queries for aggregation using default group _id field' do
      queries = Report1.new.queries
      expect(queries).to have(3).items
      expect(queries[0]).to eq(
        '$project' => {
          :_id    => 1,
          :field1 => 1,
        })
      expect(queries[1]).to eq(
        '$group' => {
          :_id    => { :_id => '$_id' },
          :field1 => { '$sum'  => '$field1' },
        })
      expect(queries[2]).to eq(
        '$project' => {
          :_id    => '$_id',
          :field1 => 1,
        })
    end

    it 'builds queries using custom one group' do
      queries = Report4.new.queries
      expect(queries).to have(3).items
      expect(queries[0]).to eq(
        '$project' => {
          :_id    => 1,
          :field1 => 1,
          :day    => 1,
        })
      expect(queries[1]).to eq(
        '$group' => {
          :_id    => { :day => '$day' },
          :field1 => { '$sum' => '$field1' },
        })
      expect(queries[2]).to eq(
        '$project' => {
          :_id    => 0,
          :day    => '$_id.day',
          :field1 => 1,
        })
    end

    class Report5
      include Mongoid::Report

      attach_to Model do
        group_by :day, :field2

        aggregation_field :field1, :field3
      end
    end

    it 'builds queries using custom one group' do
      queries = Report5.new.queries
      expect(queries).to have(3).items
      expect(queries[0]).to eq(
        '$project' => {
          :_id    => 1,
          :field1 => 1,
          :field3 => 1,
          :day    => 1,
          :field2 => 1,
        })
      expect(queries[1]).to eq(
        '$group' => {
          :_id    => { :day => '$day', :field2 => '$field2' },
          :field1 => { '$sum' => '$field1' },
          :field3 => { '$sum' => '$field3' },
        })
      expect(queries[2]).to eq(
        '$project' => {
          :_id    => 0,
          :day    => '$_id.day',
          :field2 => '$_id.field2',
          :field1 => 1,
          :field3 => 1,
        })
    end
  end

  describe '.aggregate' do
    let(:klass) { Model }
    let(:today) { DateTime.now }
    let(:yesterday) { 1.day.ago }

    it 'aggregates fields by default group _id as well' do

    end

    # it 'aggregates field by defined field of the mode' do
    #   Timecop.freeze(today) do
    #     klass.create!(day: today, field1: 1)
    #     klass.create!(day: today, field1: 1)
    #     klass.create!(day: yesterday, field1: 1)

    #     example = Report3.new
    #     rows = example.aggregate

    #     expect(rows[today][:field1]).to eq(2)
    #     expect(rows[yesterday][:field1]).to eq(1)
    #   end
    # end

  end

end
