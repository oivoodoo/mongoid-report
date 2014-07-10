require 'spec_helper'

describe Mongoid::Report::Collection do
  let(:klass) { Model }

  describe '.rows' do
    it 'use returns aggregated rows' do
      Report = Class.new do
        include Mongoid::Report

        attach_to Model do
          column :field1
        end
      end

      3.times { klass.create!(field1: 1) }

      example = Report.new
      report = example.aggregate_for(klass)
      report = report.all

      rows = report.rows
      expect(rows.size).to eq(1)
      expect(rows[0]['field1']).to eq(3)
    end
  end

  describe '.headers' do
    it 'returns columns for showing in the reports' do
      Report = Class.new do
        include Mongoid::Report

        attach_to Model do
          column :field1, :field3, :field2
        end
      end

      report = Report.new
      report = report
        .aggregate_for(klass)
        .all

      expect(report.headers).to eq(["field1", "field3", "field2"])
    end
  end
end
