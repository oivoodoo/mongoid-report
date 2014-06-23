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
        proxy_options = fields.extract_options!
        proxy_options.merge!(options)
        context.aggregation_field(*fields, proxy_options)
      end

      def group_by(*fields)
        proxy_options = fields.extract_options!
        proxy_options.merge!(options)
        context.group_by(*fields, proxy_options)
      end

      def filter(*fields)
        proxy_options = fields.extract_options!
        proxy_options.merge!(options)
        context.filter(*fields, proxy_options)
      end

      def column(*fields)
        proxy_options = fields.extract_options!
        proxy_options.merge!(options)
        context.column(*fields, proxy_options)
      end
    end

  end
end
