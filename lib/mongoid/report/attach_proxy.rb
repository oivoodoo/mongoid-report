module Mongoid
  module Report

    AttachProxy = Struct.new(:context, :collection, :options) do
      attr_reader :attach_name

      def initialize(context, collection, options)
        # Lets remove as option because of passing to the next blocks options
        @attach_name = options.delete(:as) || collection
        options = options.merge(attach_name: attach_name, for: collection)
        super(context, collection, options)
      end

      def aggregation_field(*fields)
        field_options = fields.extract_options!
        field_options.merge!(options)

        context.aggregation_field(*fields, field_options)
      end

      def group_by(*fields)
        group_options = fields.extract_options!
        group_options.merge!(options)

        context.group_by(*fields, group_options)
      end

      def filter(*fields)
        filter_options = fields.extract_options!
        filter_options.merge!(options)

        context.filter(*fields, filter_options)
      end
    end

  end
end
