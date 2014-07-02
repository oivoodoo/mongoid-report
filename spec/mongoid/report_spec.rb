require 'spec_helper'

describe Mongoid::Report do

  describe '.column' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        column :field1, for: Model
      end
    end

    it 'defines aggegration settings' do
      expect(report_klass).to be_respond_to(:settings)
    end

    it 'defines aggregation field for specific model to make queries' do
      fields = report_klass.fields(Model)
      expect(fields).to eq({ 'field1' => 'field1' })
    end
  end

 describe '.attach_to' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        attach_to Model do
          column :field1
        end
      end
    end

    it 'defines method in report class to attach report to the model' do
      expect(report_klass).to be_respond_to(:attach_to)
    end

    it 'defines field in terms of attached model' do
      fields = report_klass.fields(Model)
      expect(fields).to eq({ 'field1' => 'field1' })
    end
  end

  describe '.group_by' do
    let(:report_klass1) do
      Class.new do
        include Mongoid::Report
        group_by :day, for: Model
        column :field1, for: Model
      end
    end

    it 'defines group by method as class method' do
      expect(report_klass1).to be_respond_to(:group_by)
    end

    it 'stores group by settings under report class' do
      group_by_settings = report_klass1.settings[Model][:group_by]
      expect(group_by_settings).to eq(['day'])
    end

    let(:report_klass2) do
      Class.new do
        include Mongoid::Report
        attach_to Model do
          group_by :day
          column :field1
        end
      end
    end

    it 'defines groups in terms of attached model' do
      groups = report_klass2.groups(Model)
      expect(groups).to eq(['day'])
    end
  end

  describe '.as' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        attach_to Model, as: 'example1' do
          column :field1
        end
      end
    end

    it 'creates settings with "as" name' do
      expect(report_klass.settings).to have_key('example1')
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
      expect(report_klass.settings).to have_key('example-model1')
      expect(report_klass.settings).to have_key("example-#{Model.collection.name}")
    end
  end

  describe '.column `as` option' do
    let(:report_klass) do
      Class.new do
        include Mongoid::Report
        column :field1, for: Model, as: 'field-name'
      end
    end

    it 'creates settings with report-<attached-model-name' do
      expect(report_klass.fields(Model).keys).to eq(['field1'])
      expect(report_klass.fields(Model).values).to eq(['field-name'])
    end
  end


  describe 'two report classes' do
    it 'should have different settings' do
      ReportKlass1 = Class.new do
        include Mongoid::Report

        attach_to Model do
          column :field1
        end
      end

      ReportKlass2 = Class.new do
        include Mongoid::Report

        attach_to Model do
          column :field2
        end
      end

      expect(ReportKlass1.settings).not_to eq(ReportKlass2.settings)
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
      expect(ReportKlass1.fields(Model)).not_to eq(ReportKlass2.fields(Model))
    end
  end
end
