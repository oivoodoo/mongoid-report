module Mongoid
  module Report

    Output = Struct.new(:klass) do
      attr_accessor :collection_name

      def do(rows)
        session[collection_name].drop()
        session[collection_name].insert(rows)
      end

      def present?
        collection_name.present?
      end

      private

      def session
        klass.collection.database.session
      end
    end

  end
end
