module Mongoid
  module Report

    QueriesBuilder = Struct.new(:settings) do
      def do
        [].tap do |queries|
          queries.concat([{ '$project' => project_query }])
          queries.concat([{ '$group'   => group_query }])
          queries.concat([{ '$project' => project_group_fields_query }])
        end
      end

      private

      def groups
        @group_by ||= settings.fetch(:group_by, [])
      end

      def fields
        @fields ||= settings[:fields].select do |field, _|
          !settings[:columns].include?(field.to_sym)
        end
      end

      def in_fields
        @in_fields ||= fields.keys
      end

      def output_fields
        @output_fields ||= fields.values
      end

      def all_fields
        [:_id]
          .concat(in_fields)
          .concat(groups)
      end

      # All queries are going using 3 steps:
      # - project query for selecting only required fields and decrease the
      # memory usage on aggregation.
      # - group by query using the explicit declarations in the columns
      # - project query after the grouping the data and selecting only required
      # columns for storing to the row.

      # Example: { '$project' => { :field1 => 1 } }
      def project_query
        all_fields.inject({}) do |hash, field|
          hash.merge!(field => 1)
        end
      end

      GROUP_TEMPLATE = "$%s"
      def group_query
        {}.tap do |query|
          query[:_id] = {}

          groups.inject(query[:_id]) do |hash, group|
            hash.merge!(group => GROUP_TEMPLATE % group)
          end

          in_fields.inject(query) do |hash, field|
            next hash if groups.include?(field)
            hash.merge!(field => { '$sum' => GROUP_TEMPLATE % field })
          end
        end
      end

      PROJECT_TEMPLATE = "$_id.%s"
      def project_group_fields_query
        {}.tap do |query|
          if groups == [:_id]
            query[:_id] = '$_id'
          else
            query[:_id] = 0

            keys = fields.keys
            groups.inject(query) do |hash, group|
              next hash unless keys.include?(group)
              hash.merge!(group => PROJECT_TEMPLATE % group)
            end
          end

          fields.inject(query) do |hash, (field, name)|
            next hash if query.include?(field)
            hash.merge!(name => "$#{field}")
          end
        end
      end
    end

  end
end
