require 'spec_helper'

describe Mongoid::Report do

  describe '.aggregation_field' do
    it 'defines aggegration settings' do
      expect(Report1).to be_respond_to(:settings)
    end

    it 'defines aggregation field for specific model to make queries' do
      fields = Report1.fields(Model)
      expect(fields).to eq({ field1: :field1 })
    end
  end

  describe '.attach_to' do
    it 'defines method in report class to attach report to the model' do
      expect(Report2).to be_respond_to(:attach_to)
    end

    it 'defines field in terms of attached model' do
      fields = Report2.fields(Model)
      expect(fields).to eq({ field1: :field1 })
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
      expect(groups).to eq([:day])
    end
  end

  class Report6
    include Mongoid::Report

    attach_to Model, as: 'example1' do
      aggregation_field :field1
    end
  end

  describe '.as' do
    it 'creates settings with "as" name' do
      expect(Report6.settings).to have_key('example1')
    end
  end

  class Report7
    include Mongoid::Report

    report 'example' do
      attach_to Model, as: 'model1' do
        aggregation_field :field1
      end

      attach_to Model do
        aggregation_field :field1
      end
    end
  end

  describe '.report' do
    it 'creates settings with report-<attached-model-name' do
      expect(Report7.settings).to have_key('example-model1')
      expect(Report7.settings).to have_key("example-#{Model.collection.name}")
    end
  end

  class Report10
    include Mongoid::Report

    aggregation_field :field1, for: Model, as: 'field-name'
  end

  describe '.aggregation_field `as` option' do
    it 'creates settings with report-<attached-model-name' do
      expect(Report10.fields(Model).keys).to eq([:field1])
      expect(Report10.fields(Model).values).to eq(['field-name'])
    end
  end

end
