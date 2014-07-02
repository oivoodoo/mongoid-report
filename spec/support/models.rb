class Model
  include Mongoid::Document

  field :field1, type: Integer, default: 0
  field :field2, type: Integer, default: 0
  field :field3, type: Integer, default: 0

  field :day,    type: Date
end
