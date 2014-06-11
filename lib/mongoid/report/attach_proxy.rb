module Mongoid

  module Report

    AttachProxy = Struct.new(:context, :collection) do
      def aggregation_field(*fields)
        context.aggregation_field(*fields, for: collection)
      end

      def group_by(*fields)
        context.group_by(*fields, for: collection)
      end
    end

  end

end
