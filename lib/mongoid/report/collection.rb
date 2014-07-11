require 'delegate'

module Mongoid
  module Report

    class Collection
      def initialize(context, rows, fields, columns, mapping)
        @context = context
        @rows    = rows
        @fields  = fields
        @columns = columns
        @mapping = mapping
        @rows    = Rows.new(compile_rows)
      end

      class Rows < SimpleDelegator ; end

      attr_reader :rows

      def headers
        @fields
      end

      def summary
        @summary ||= @rows.reduce(Hash.new{|h, k| h[k] = 0}) do |summary, row|
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
            summary[name] = function.call(@context, row, { mapping: @mapping, summary: true })
          end

          summary
        end
      end

      private

      def compile_rows
        @rows.map do |row|
          @columns.each do |name, function|
            next unless @fields.include?(name)
            row[name] = function.call(@context, row, { mapping: @mapping, summary: false })
          end

          row
        end
      end

    end

  end
end
