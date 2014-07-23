module Mongoid
  module Report

    class Input
      attr_accessor :collection_name

      def present?
        collection_name.present?
      end

      def collection
        @collection ||= Mongoid::Report::Collections.get(collection_name)
      end
    end

  end
end
