module Mongoid
  module Report

    class Output
      attr_accessor :collection_name, :options

      def do(rows)
        drop()
        collection.insert(rows)
      end

      def present?
        collection_name.present?
      end

      def drop
        return collection.drop() unless options[:drop].present?

        # We will use custom way for dropping the collection or removing the
        # records partially
        collection.find(options[:drop]).remove_all()
      end

      private

      def collection
        @collection ||= Collections.get(collection_name)
      end
    end

  end
end
