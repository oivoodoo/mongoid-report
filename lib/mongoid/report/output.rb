module Mongoid
  module Report

    class Output
      attr_accessor :collection_name

      def do(rows)
        collection.drop()
        collection.insert(rows)
      end

      def present?
        collection_name.present?
      end

      private

      def collection
        @collection ||= Collections.get(collection_name)
      end
    end

  end
end
