module Mongoid
  module Report

    Scope = Struct.new(:context, :report_name) do
      def query(conditions)
        queries.concat([conditions])
        self
      end

      # We need to add grouping conditions when user needs it.
      def yield
        return self if @yielded

        queries.concat(context.queries(report_name))
        @yielded = true

        self
      end

      def all
        self.yield unless yielded?
        Collection.new(klass.collection.aggregate(queries), fields)
      end

      private

      def yielded?
        @yielded
      end

      def queries
        @queries ||= []
      end

      def klass
        context.class.settings_property(report_name, :for)
      end

      def fields
        context.class.settings_property(report_name, :fields)
      end
    end

  end
end
