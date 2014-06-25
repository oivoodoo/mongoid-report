module Mongoid
  module Report

    ScopeCollection = Struct.new(:context) do
      def scopes
        @scopes ||= modules.map do |key|
          Scope.new(context, key)
        end
      end

      def query(conditions = {})
        scopes.each do |scope|
          scope.query(conditions)
        end
        self
      end

      def yield
        scopes.each do |scope|
          scope.yield
        end
        self
      end

      def all
        {}.tap do |hash|
          if Mongoid::Report::Config.use_threads_on_aggregate
            scopes.map do |scope|
              Thread.new do
                hash[scope.report_name] = scope.all
              end
            end.map(&:join)
          else
            scopes.each do |scope|
              hash[scope.report_name] = scope.all
            end
          end
        end
      end

      private

      def modules
        context.settings.keys
      end
    end

  end
end
