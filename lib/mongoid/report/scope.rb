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
        queries = compile_queries
        Collection.new(klass.collection.aggregate(queries), fields, columns)
      end

      private

      def compile_queries
        queries.map do |query|
          query.deep_dup.each do |function_name, values|
            values.each do |name, value|
              value = value.call(context) if value.respond_to?(:call)
              query[function_name][name] = value
            end
          end

          query
        end
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
