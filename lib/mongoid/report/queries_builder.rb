module Mongoid
  module Report

    QueriesBuilder = Struct.new(:context, :klass) do
      def do
        [].tap do |queries|
          queries.concat([{ '$project' => project_query }])
          queries.concat([{ '$group'   => group_query }])
          queries.concat([{ '$project' => project_group_fields_query }])
        end
      end

      private

      def groups
        context.groups(klass)
      end

      def fields
        @fields ||= begin
          columns = context.columns(klass)

          context.fields(klass).select do |field|
            !columns.include?(field.to_sym)
          end
        end
      end

      def all_fields
        [:_id]
          .concat(fields)
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

          fields.inject(query) do |hash, field|
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

            groups.inject(query) do |hash, group|
              hash.merge!(group => PROJECT_TEMPLATE % group)
            end
          end

          fields.inject(query) do |hash, field|
            next hash if groups.include?(field)
            hash.merge!(field => "$#{field}")
          end
        end
      end
    end

  end
end
