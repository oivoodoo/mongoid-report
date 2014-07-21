require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }

  it 'allows to save options per report and attached model' do
    2.times { klass.create!(field1: 1) }

    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          columns :'new-field' => ->(context, row, options) { row[options[:mapping]['field3'].to_s] }
          mapping :'field3' => :field1

          column :field1, :'new-field'
        end
      end
    end

    report = report_klass.new
    report = report.aggregate_for('example-models')
    report = report.all

    rows = report.rows

    expect(rows.size).to eq(1)
    expect(rows[0]['field1']).to eq(2)
    expect(rows[0]['new-field']).to eq(2)
  end
end
