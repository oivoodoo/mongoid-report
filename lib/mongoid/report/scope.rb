require 'set'

module Mongoid
  module Report

    Scope = Struct.new(:context, :report_module, :report_name) do
      def query(conditions = {})
        queries.concat([conditions]) unless conditions.empty?
        self
      end

      # We need to add grouping conditions when user needs it.
      def yield
        return self if @yielded

        queries.concat(context.queries(report_module, report_name))
        @yielded = true

        self
      end

      def out(collection_name, options = {})
        output.collection_name = collection_name
        output.options = options
        self
      end

      def in(collection_name)
        input.collection_name = collection_name
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
            rows.concat(Array(collection.aggregate(q)))
          end
        end
        threads.map(&:join)

        merger = Mongoid::Report::Merger.new(groups)
        merger.do(rows)
      end

      def all_inline(aggregation_queries)
        Array(collection.aggregate(aggregation_queries))
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
        compiled = Set.new

        queries.each do |query|
          next compiled << query if query.has_key?("$project") || query.has_key?('$group')

          query.deep_dup.tap do |new_query|
            new_query.each do |function_name, values|

              if values.respond_to?(:call)
                new_query[function_name] = values.call(context)
              else
                values.each do |name, value|
                  if value.respond_to?(:call)
                    value = value.call(context)
                  end

                  unless value.present?
                    # In case we don't have value for applying match, lets skip
                    # this type of the queries.
                    new_query.delete(function_name)
                  else
                    new_query[function_name][name] = value
                  end
                end

              end # values.is_a?(Proc)
            end # new_query.each

            compiled << new_query if new_query.present?
          end
        end

        compiled.to_a
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
          if input.present?
            # Using default session to mongodb we can automatically provide
            # access to collection.
            input.collection
          else
            klass = context.report_module_settings[report_module][:reports][report_name][:collection]
            Collections.get(klass)
          end
        end
      end

      def batches
        @batches ||= Mongoid::Report::Batches.new(
          context.batches(report_module, report_name))
      end

      def output
        @output ||= Mongoid::Report::Output.new
      end

      def input
        @input ||= Mongoid::Report::Input.new
      end

      def groups
        @groups ||= context.groups(report_module, report_name)
      end

      def fields
        # We need to use here only output field names it could be different
        # than defined colunms, Example: field1: 'report-field-name'
        context.fields(report_module, report_name)
      end

      def columns
        context.columns(report_module, report_name)
      end

      def mapping
        context.mapping(report_module, report_name)
      end
    end

  end
end
