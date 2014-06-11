module Mongoid
  module Report

    class Collection
      include Enumerable

      def initialize(rows, fields)
        @rows   = rows
        @fields = fields
      end

      def each(&block)
        @rows.each do |row|
          yield row
        end
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
