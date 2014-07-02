require 'delegate'

module Mongoid
  module Report

    class Collection < SimpleDelegator
      def initialize(context, rows, fields, columns)
        @context = context
        @rows    = rows
        @fields  = fields
        @columns = columns
        @rows    = compile_rows

        # Collection should behave like Array using delegator method.
        super(@rows)
      end

      def compile_rows
        @rows.map do |row|
          @columns.each do |name, function|
            next unless @fields.include?(name)
            row[name] = function.call(@context, row, { summary: false })
          end

          row
        end
      end

      def summary
        @summary ||= reduce(Hash.new{|h, k| h[k] = 0}) do |summary, row|
          # Find summary for aggregated rows
          @fields.each do |field|
            # Don't apply for dynamic calculated columns lets wait until we get
            # all summaried mongo columns and then apply dynamic columns
            # calculations.
            next if @columns.has_key?(field)
            summary[field] += row[field]
          end

          # Apply dynamic columns for summarized row
          @columns.each do |name, function|
            next unless @fields.include?(name)
            summary[name] = function.call(@context, row, { summary: true })
          end

          summary
        end
      end

    end

  end
end
