module Mongoid
  module Report

    QueriesBuilder = Struct.new(:settings) do
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

      def all_fields
        [:_id]
          .concat(fields)
          .concat(groups)
      end

      # Example: { '$project' => { :field1 => 1 } }
      def query1
        all_fields.inject({}) do |hash, field|
          hash.merge!(field => 1)
        end
      end

      GROUP_TEMPLATE = "$%s"
      def query2
        {}.tap do |query|
          query[:_id] = {}

          groups.inject(query[:_id]) do |hash, group|
            hash.merge!(group => GROUP_TEMPLATE % group)
          end

          fields.inject(query) do |hash, field|
            hash.merge!(field => { '$sum' => GROUP_TEMPLATE % field })
          end
        end
      end

      PROJECT_TEMPLATE = "$_id.%s"
      def query3
        {}.tap do |query|
          if groups == [:_id]
            query[:_id] = '$_id'
          else
            query[:_id] = 0

            groups.inject(query) do |hash, group|
              hash.merge!(group => PROJECT_TEMPLATE % group)
            end
          end

          fields.inject(query) do |hash, field|
            hash.merge!(field => 1)
          end
        end
      end

      def do
        [].tap do |queries|
          queries.concat([{ '$project' => query1 }])
          queries.concat([{ '$group'   => query2 }])
          queries.concat([{ '$project' => query3 }])
        end
      end
    end

  end
end
