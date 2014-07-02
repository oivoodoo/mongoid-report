require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }

  it 'allows to save options per report and attached model' do
    2.times { klass.create!(field1: 1) }

    Report = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          columns :'new-field' => ->(context, row, options) { row[context.mapping('example-models')['field3'].to_s] }
          mapping :'field3' => :field1

          column :field1, :'new-field'
        end
      end
    end
    example = Report.new

    rows = example.aggregate_for('example-models')
    rows = rows.all

    expect(rows.size).to eq(1)
    expect(rows[0]['field1']).to eq(2)
    expect(rows[0]['new-field']).to eq(2)
  end
end
