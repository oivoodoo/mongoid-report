module Mongoid
  module Report

    Scope = Struct.new(:context, :report_name) do
      def query(conditions = {})
        queries.concat([conditions]) unless conditions.empty?
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

        aggregation_queries = compile_queries
        rows = klass.collection.aggregate(aggregation_queries)

        Collection.new(context, rows, fields, columns)
      end

      private

      def compile_queries
        compiled = queries.map do |query|
          next query unless query.has_key?("$match")

          query.deep_dup.tap do |new_query|
            new_query.each do |function_name, values|
              values.each do |name, value|
                if value.respond_to?(:call)
                  value = value.call(context)
                end

                new_query[function_name][name] = value
              end
            end
          end
        end

        compiled
      end

      def yielded?
        @yielded
      end

      def queries
        @queries ||= []
      end

      def klass
        context.report_module_settings[report_name][:for]
      end

      def fields
        # We need to use here only output field names it could be different
        # than defined colunms, Example: field1: 'report-field-name'
        context.report_module_settings[report_name][:fields].values
      end

      def columns
        context.report_module_settings[report_name][:columns]
      end
    end

  end
end
