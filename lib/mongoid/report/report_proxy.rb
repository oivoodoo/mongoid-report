require 'securerandom'

module Mongoid
  module Report

    ReportProxy = Struct.new(:context, :name) do
      def attach_proxy
        @attach_proxy ||= begin
          AttachProxy.new(context, nil, report_module: name)
        end
      end
      delegate :column, :columns, :mapping, :group_by, :match,
        :batches, to: :attach_proxy

      def attach_to(*fields, &block)
        options = fields.extract_options!
        model   = fields[0]

        report_name = options.delete(:as) || Collections.name(model)
        options.merge!(report_module: name, as: report_name)

        context.attach_to(*fields, options, &block)
      end
    end

  end
end
