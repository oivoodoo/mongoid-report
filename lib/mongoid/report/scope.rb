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
            rows.concat(klass.collection.aggregate(q))
          end
        end
        threads.map(&:join)

        merger = Mongoid::Report::Merger.new(groups)
        merger.do(rows)
      end

      def all_inleine(aggregation_queries)
        klass.collection.aggregate(aggregation_queries)
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

      def klass
        context.report_module_settings[report_name][:for]
      end

      def batches
        @batches ||= Mongoid::Report::Batches.new(
          context.report_module_settings[report_name][:batches])
      end

      def output
        @output ||= Mongoid::Report::Output.new(klass)
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
