module Mongoid
  module Report

    # We are using this class to combine results by group by fields.
    Merger = Struct.new(:groups) do
      def do(rows)
        # Merge by groups.
        rows
          .group_by { |row| groups.map { |group| row[group] }.join('-') }
          .values
          .map { |array_row| combine(array_row) }
      end

      private

      def combine(rows)
        rows.inject(Hash.new {|h,k| h[k] = 0}) do |row, lines|
          lines.each do |key, value|
            next row[key] = value if groups.include?(key)
            row[key] += value
          end

          row
        end
      end
    end

  end
end
