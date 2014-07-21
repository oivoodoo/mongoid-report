module Mongoid
  module Report
    # We are using this class to combine results by group by fields.
    Merger = Struct.new(:groups) do
      def do(rows)
        # Merge by groups.
        groups.each do |group|
          rows = rows
            .group_by { |row| row[group] }
            .values
            .map { |array_row| combine(array_row) }
          end

        rows
      end

      private

      def combine(rows)
        rows.inject(Hash.new {|h,k| h[k] = 0}) do |row, lines|
          lines.each do |key, value|
            next row[key] = value if groups.include?(key)
            row[key] += value
          end

          row
        end
      end
    end

    # Split the queries into threads.
    Batches = Struct.new(:settings, :conditions) do
      DEFAULT_THREAD_POOL_SIZE = 5

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
        range.each_slice(size.ceil).map do |r|
          yield r
        end
      end

      def size
        range.count.to_f / settings['pool_size'].to_f
      end

      def present?
        settings['pool_size'].present? &&
          conditions.present?
      end
    end

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
        @output ||= Output.new(klass)
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
