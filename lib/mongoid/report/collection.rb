require 'delegate'

module Mongoid
  module Report

    class Collection < SimpleDelegator
      def initialize(context, rows, fields, columns)
        @context = context
        @rows    = rows
        @fields  = fields
        @columns = columns

        # Apply dyncamic columns in context of row and apply indifferent access
        # for the rows.
        rows = compile_dynamic_fields(rows, columns)

        # Collection should behave like Array using delegator method.
        super(rows)
      end

      def summary
        @summary ||= reduce(Hash.new{|h, k| h[k] = 0}) do |summary, row|
          @fields.each do |field|
            summary[field] += row[field.to_s]
          end

          summary
        end.with_indifferent_access
      end

      private

      def compile_dynamic_fields(rows, columns)
        rows.map do |row|
          @columns.each do |name, function|
            row[name] = function.call(@context, row)
          end

          row.with_indifferent_access
        end
      end
    end

  end
end
