require 'spec_helper'

describe Mongoid::Report do
  it 'should creates settings in case of missing block' do
    report_klass = Class.new do
      include Mongoid::Report

      report 'example' do
        attach_to Model do ; end
      end
    end

    expect(report_klass.settings['example']).to be
    expect(report_klass.settings['example'][:reports]['models']).to be
  end
end
