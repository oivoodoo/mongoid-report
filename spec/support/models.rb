class Model
  include Mongoid::Document

  field :field1, type: Integer, default: 0
  field :field2, type: Integer, default: 0
  field :field3, type: Integer, default: 0

  field :day,    type: Date
end

class Report1
  include Mongoid::Report

  aggregation_field :field1, for: Model
end

class Report2
  include Mongoid::Report

  attach_to Model do
    aggregation_field :field1
  end
end

class Report3
  include Mongoid::Report

  group_by :day, for: Model

  aggregation_field :field1, for: Model
end

class Report4
  include Mongoid::Report

  attach_to Model do
    group_by :day

    aggregation_field :field1
  end
end
