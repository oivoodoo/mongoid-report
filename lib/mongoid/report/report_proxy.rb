module Mongoid

  module Report

    ReportProxy = Struct.new(:context, :name) do

      def attach_to(model, options = {}, &block)
        as = options.fetch(:as) { model.collection.name }

        options.merge!(as: "#{name}-#{as}") if as

        context.attach_to(model, options, &block)
      end

    end
  end
end
