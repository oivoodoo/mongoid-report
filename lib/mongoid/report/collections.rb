module Mongoid
  module Report

    class Collections
      def self.get(collection_name)
        Mongoid.session(:default)[collection_name]
      end

      def self.name(model)
        model && model.respond_to?(:collection) ?
          model.collection.name : model
      end
    end

  end
end
