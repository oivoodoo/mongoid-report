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
        scopes.inject({}) do |hash, scope|
          hash[scope.report_name] = scope.all
          hash
        end
      end

      private

      def modules
        context.settings.keys
      end
    end

  end
end
