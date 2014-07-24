require 'spec_helper'

describe Mongoid::Report do

  describe '.column' do
    let(:report_klass) do
      Class.new do
        def self.name ; 'report-klass' ; end
        include Mongoid::Report
        column :field1, collection: Model
      end
    end

    it 'defines aggegration settings' do
      expect(report_klass).to be_respond_to(:settings)
    end

    it 'defines aggregation field for specific model to make queries' do
      fields = report_klass.settings['report-klass'][:reports]['models'][:fields]
      expect(fields).to eq(['field1'])
    end
  end

  describe '.attach_to' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end
        attach_to Model do
          column :field1
        end
      end
    end

    it 'defines method in report class to attach report to the model' do
      expect(report_klass).to be_respond_to(:attach_to)
    end

    it 'defines field in terms of attached model' do
      fields = report_klass.settings['report-klass'][:reports]['models'][:fields]
      expect(fields).to eq(['field1'])
    end
  end

  describe '.group_by' do
    let(:report_klass1) do
      Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end
        group_by :day, collection: Model
        column :field1, collection: Model
      end
    end

    it 'defines group by method as class method' do
      expect(report_klass1).to be_respond_to(:group_by)
    end

    it 'stores group by settings under report class' do
      settings = report_klass1.settings['report-klass'][:reports]['models'][:group_by]
      expect(settings).to eq(['day'])
    end

    let(:report_klass2) do
      Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end
        attach_to Model do
          group_by :day
          column :field1
        end
      end
    end

    it 'defines groups in terms of attached model' do
      settings = report_klass2.settings['report-klass'][:reports]['models'][:group_by]
      expect(settings).to eq(['day'])
    end
  end

  describe '.as' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass' ; end
        attach_to Model, as: 'example1' do
          column :field1
        end
      end
    end

    it 'creates settings with "as" name' do
      expect(report_klass.settings['report-klass'][:reports]).to have_key('example1')
    end
  end

  describe '.report' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        report 'example' do
          attach_to Model, as: 'model1' do
            column :field1
          end

          attach_to Model do
            column :field1
          end
        end
      end
    end

    it 'creates settings with report-<attached-model-name' do
      reports = report_klass.settings['example'][:reports].keys
      expect(reports).to include('model1')
      expect(reports).to include('models')
    end
  end

  describe 'two report classes' do
    it 'should have different settings' do
      report_klass1 = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass1' ; end

        attach_to Model do
          column :field1
        end
      end

      report_klass2 = Class.new do
        include Mongoid::Report
        def self.name ; 'report-klass2' ; end

        attach_to Model do
          column :field2
        end
      end

      expect(report_klass1.settings).not_to eq(report_klass2.settings)
    end

    class ReportKlass
      include Mongoid::Report
    end

    class ReportKlass1 < ReportKlass
      attach_to Model do
        column :field1
      end
    end

    class ReportKlass2 < ReportKlass
      attach_to Model do
        column :field2
      end
    end

    it 'should have different settings for inherited classes' do
      settings1 = ReportKlass1.settings['ReportKlass1'][:reports]['models']
      settings2 = ReportKlass2.settings['ReportKlass2'][:reports]['models']
      expect(settings1).not_to eq(settings2)
    end
  end
end
