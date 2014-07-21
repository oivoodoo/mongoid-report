module Mongoid
  module Report

    # Split the queries into threads.
    Batches = Struct.new(:settings, :conditions) do
      DEFAULT_THREAD_POOL_SIZE = 5

      def initialize(settings = {}, conditions = {})
        if settings.nil? || settings.empty?
          settings = { 'pool_size' => DEFAULT_THREAD_POOL_SIZE }
        end

        super(settings, conditions)
      end

      def field
        conditions.keys[0]
      end

      def range
        conditions.values[0]
      end

      def map
        range.each_slice(size.ceil).map do |r|
          yield r
        end
      end

      def size
        range.count.to_f / settings['pool_size'].to_f
      end

      def present?
        settings['pool_size'].present? &&
          conditions.present?
      end
    end

  end
end
