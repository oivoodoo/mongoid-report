require 'spec_helper'

describe Mongoid::Report do
  it 'should stores global queries for each defined attach_to blocks' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        match field1: 1

        attach_to Model, as: 'models1' do ; end
        attach_to Model, as: 'models2' do
          column :field2
        end
      end
    end

    report = report_klass.new
    queries1 = report.report_module_settings['example'][:reports]['models1'][:queries]
    queries2 = report.report_module_settings['example'][:reports]['models2'][:queries]

    expect(queries1).to eq([
      { '$match' => { :field1 => 1 }},
      { '$project' => { :_id => 1 }},
      { '$group' => { :_id => {} } },
      { '$project' => { :_id => 0 } },
    ])
    expect(queries2).to eq([
      { '$match' => { :field1 => 1 }},
      { '$project' => { :_id => 1, 'field2' => 1 }},
      { '$group' => { :_id => {}, 'field2'=>{'$sum'=>'$field2'} } },
      { '$project' => { :_id => 0, 'field2' => '$field2' } },
    ])
  end
end
