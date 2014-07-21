require 'securerandom'

module Mongoid
  module Report

    ReportProxy = Struct.new(:context, :name) do
      def attach_to(*fields, &block)
        options = fields.extract_options!
        model   = fields[0]

        as = options.fetch(:as) do
          if model
            model.collection.name
          end
        end

        if as
          options.merge!(as: "#{name}-#{as}")
        else
          options.merge!(as: name)
        end

        context.attach_to(*fields, options, &block)
      end
    end

  end
end
