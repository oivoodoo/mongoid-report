require 'thread'

module Mongoid
  module Report

    ScopeCollection = Struct.new(:context) do
      def initialize(context)
        @mutex = Mutex.new
        super
      end

      def scopes
        @scopes ||= [].tap do |collection|
          context.settings.each do |report_module, module_settings|
            module_settings[:reports].each do |report_name, _report_settings|
              collection << Scope.new(context, report_module, report_name)
            end
          end
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

      def in_batches(conditions)
        scopes.each do |scope|
          scope.in_batches(conditions)
        end
        self
      end

      def all
        Hash.new { |h, k| h[k] = {} }.tap do |hash|
          if Mongoid::Report::Config.use_threads_on_aggregate
            scopes.map do |scope|
              Thread.new do
                rows = scope.all

                @mutex.synchronize do
                  hash[scope.report_module][scope.report_name] = rows
                end
              end
            end.map(&:join)
          else
            scopes.each do |scope|
              hash[scope.report_module][scope.report_name] = scope.all
            end
          end
        end
      end

    end

  end
end
