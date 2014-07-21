module Mongoid
  module Report

    Scope = Struct.new(:context, :report_name, :options) do
      def initialize(context, report_name, options = {})
        super
      end

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

      def out(collection_name)
        output.collection_name = collection_name
        self
      end

      def all_in_batches(aggregation_queries)
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

            # if groups == [batch.field]
            rows.concat(collection.aggregate(q))
          end
        end
        threads.map(&:join)

        merger = Mongoid::Report::Merger.new(groups)
        merger.do(rows)
      end

      def all_inline(aggregation_queries)
        collection.aggregate(aggregation_queries)
      end

      def all
        self.yield unless yielded?

        aggregation_queries = compile_queries

        rows = if batches.present?
          all_in_batches(aggregation_queries)
        else
          all_inline(aggregation_queries)
        end

        # in case if we want to store rows to collection
        if output.present?
          output.do(rows)
        end

        Collection.new(context, rows, fields, columns, mapping)
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

      # Different usage for this method:
      # - attach_to method contains collection name as first argument
      # - attach_to method contains mongoid model
      # - aggregate_for method contains attach_to proc option for calculating
      # collection name.
      def collection
        @collection ||= begin
          # In case if we are using dynamic collection name calculated by
          # passing attach_to proc to the aggregate method.
          if options[:attach_to]
            collection_name = options[:attach_to].call
            # Using default session to mongodb we can automatically provide
            # access to collection.
            Collections.get(collection_name)
          else
            klass = context.report_module_settings[report_name][:for]

            if klass.respond_to?(:collection)
              klass.collection
            else
              # In case if we are using collection name instead of mongoid
              # model passed to the attach_to method.
              Collections.get(klass)
            end
          end
        end
      end

      def batches
        @batches ||= Mongoid::Report::Batches.new(
          context.report_module_settings[report_name][:batches])
      end

      def output
        @output ||= Mongoid::Report::Output.new
      end

      def groups
        @groups ||= context.report_module_settings[report_name][:group_by]
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
