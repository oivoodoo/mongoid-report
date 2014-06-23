require 'delegate'

module Mongoid
  module Report

    class Collection < SimpleDelegator
      def initialize(rows, fields, columns)
        @rows    = rows
        @fields  = fields
        @columns = columns
        super(rows)
        compile_dynamic_fields(columns)
      end

      def summary
        @summary ||= reduce(Hash.new{|h, k| h[k] = 0}) do |summary, row|
          @fields.each do |field|
            summary[field] += row[field.to_s]
          end

          summary
        end
      end

      private

      def compile_dynamic_fields(columns)
        self.each do |row|
          @columns.each do |name, function|
            row[name] = function.call(row)
          end
        end
      end
    end

  end
end
