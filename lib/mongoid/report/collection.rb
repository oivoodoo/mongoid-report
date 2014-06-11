require 'delegate'

module Mongoid
  module Report

    class Collection < SimpleDelegator
      def initialize(rows, fields)
        @rows   = rows
        @fields = fields
        super(rows)
      end

      def summary
        @summary ||= reduce(Hash.new{|h, k| h[k] = 0}) do |summary, row|
          @fields.each do |field|
            summary[field] += row[field.to_s]
          end

          summary
        end
      end
    end

  end
end
