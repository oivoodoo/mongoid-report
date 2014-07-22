require 'spec_helper'

describe Mongoid::Report do
  let(:klass) { Model }

  it 'allows to specify dynamic name for attach_to option' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to 'pregenerated' do
          group_by :field1
          column :field3
        end

        attach_to Model do
          group_by :field1, :field2
          column :field3
        end
      end
    end

    klass.create!(field1: 1, field2: 1, field3: 1)
    klass.create!(field1: 1, field2: 2, field3: 1)

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models')
    scoped = scoped
      .out('new-collection')
      .all

    expect(scoped.rows.size).to eq(2)
    expect(scoped.summary['field3']).to eq(2)

    scoped = report.aggregate_for('example', 'pregenerated')
    scoped = scoped
      .in('new-collection')
      .all

    expect(scoped.rows.size).to eq(1)
    expect(scoped.rows[0]['field3']).to eq(2)
    expect(scoped.summary['field3']).to eq(2)
  end


  it 'should be possible to define column and other methods out of the attach_to scope' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        columns :field4 => ->(context, row, options) { row['field3'] }

        column :field3, :field4

        attach_to 'pregenerated' do
          group_by :field1
        end

        attach_to Model do
          group_by :field1, :field2
        end
      end
    end

    klass.create!(field1: 1, field2: 1, field3: 1)
    klass.create!(field1: 1, field2: 2, field3: 1)

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models')
    scoped = scoped
      .out('new-collection')
      .all
    expect(scoped.rows.size).to eq(2)
    expect(scoped.summary['field3']).to eq(2)

    scoped = report.aggregate_for('example', 'pregenerated')
    scoped = scoped
      .in('new-collection')
      .all

    expect(scoped.rows.size).to eq(1)
    expect(scoped.rows[0]['field3']).to eq(2)
    expect(scoped.rows[0]['field4']).to eq(2)
    expect(scoped.summary['field3']).to eq(2)
  end
end
