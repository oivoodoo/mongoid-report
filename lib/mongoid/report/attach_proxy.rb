module Mongoid
  module Report

    AttachProxy = Struct.new(:context, :collection, :options) do
      def aggregation_field(*fields)
        context.aggregation_field(*fields, options.merge(for: collection))
      end

      def group_by(*fields)
        context.group_by(*fields, options.merge(for: collection))
      end
    end

  end
end
