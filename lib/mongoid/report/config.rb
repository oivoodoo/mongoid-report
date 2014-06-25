module Mongoid
  module Report

    class Config
      class_attribute :use_threads_on_aggregate

      self.use_threads_on_aggregate = false
    end

  end
end
