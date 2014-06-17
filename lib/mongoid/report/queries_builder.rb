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
        @group_by ||= begin
          if settings[:group_by].size == 0
            [:_id]
          else
            settings[:group_by]
          end
        end
      end

      def fields
        @fields ||= settings[:fields]
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

            groups.inject(query) do |hash, group|
              hash.merge!(group => PROJECT_TEMPLATE % group)
            end
          end

          fields.inject(query) do |hash, (field, name)|
            hash.merge!(name => "$#{field}")
          end
        end
      end
    end

  end
end
