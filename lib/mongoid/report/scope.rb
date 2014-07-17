module Mongoid
  module Report

    Batches = Struct.new(:settings, :conditions) do
      DEFAULT_THREAD_POOL_SIZE = 3

      def initialize(settings = {}, conditions = {})
        if settings.nil? || settings.empty?
          settings = { 'pool_size' => DEFAULT_THREAD_POOL_SIZE }
        end

        super(settings, conditions)
      end

      def field
        conditions.keys[0]
      end

      def range
        conditions.values[0]
      end

      def map
        range.each_slice(size).map do |r|
          yield r
        end
      end

      def size
        range.count / settings['pool_size']
      end

      def present?
        settings['pool_size'].present? &&
          conditions.present?
      end
    end

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

        if batches.present?
          # Lets assume we have only one field for making splits for the
          # aggregation queries.
          rows = []

          threads = batches.map do |r|
            # For now we are supporting only data fields for splitting up the
            # queries.
            range_match = r.map { |time| time.to_date.mongoize }

            Thread.new do
              q =
                ['$match' => { batches.field => { '$gte' => range_match.first, '$lte' => range_match.last } }] +
                aggregation_queries
              rows.concat(klass.collection.aggregate(q))
            end
          end
          threads.map(&:join)

          Collection.new(context, rows, fields, columns, mapping)
        else
          # when we have no batches to run and lets do it inline.
          rows = klass.collection.aggregate(aggregation_queries)
          Collection.new(context, rows, fields, columns, mapping)
        end
      end

      def in_batches(conditions)
        batches.conditions = conditions
        self
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

      def batches
        @batches ||= Mongoid::Report::Batches.new(
          context.report_module_settings[report_name][:batches])
      end

      def fields
        # We need to use here only output field names it could be different
        # than defined colunms, Example: field1: 'report-field-name'
        context.report_module_settings[report_name][:fields].values
      end

      def columns
        context.report_module_settings[report_name][:columns]
      end

      def mapping
        context.report_module_settings[report_name][:mapping]
      end
    end

  end
end
