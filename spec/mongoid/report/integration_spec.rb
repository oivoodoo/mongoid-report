require 'spec_helper'

describe Mongoid::Report do
  it 'works fine on multiple requests' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do
          match field2: 2
          column :field1
        end
      end
    end

    Model.create(field1: 1, field2: 1)
    Model.create(field1: 1, field2: 2)

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models').all
    queries1 = report.report_module_settings['example'][:reports]['models'][:queries].deep_dup

    report = report_klass.new
    scoped = report.aggregate_for('example', 'models').all
    queries2 = report.report_module_settings['example'][:reports]['models'][:queries].deep_dup

    expect(queries1).to eq(queries2)
  end
end
