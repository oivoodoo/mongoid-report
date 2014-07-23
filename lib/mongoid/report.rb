require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

require_relative 'report/config'
require_relative 'report/queries_builder'
require_relative 'report/attach_proxy'
require_relative 'report/collection'
require_relative 'report/batches'
require_relative 'report/merger'
require_relative 'report/collections'
require_relative 'report/output'
require_relative 'report/input'
require_relative 'report/scope'
require_relative 'report/scope_collection'
require_relative 'report/report_proxy'

module Mongoid
  module Report
    extend ActiveSupport::Concern

    included do
      extend ClassMethods

      class_attribute :settings

      self.settings = {}

      def self.inherited(subclass)
        subclass.settings = self.settings.dup
      end

      # Variable for copying internal class settings to the instance because of
      # possible modifications in case of using filters with lambda
      # expressions.
      attr_reader :report_module_settings

      def initialize_report_module
        # Lets store settings under created instance.
        @report_module_settings = self.class.settings.dup

        @report_module_settings.each do |report_module, module_configuration|
          # Lets do not run queries builder in case of missing queries or group
          # by parameters
          unless module_configuration[:queries].empty? && module_configuration[:group_by].empty?
            builder = QueriesBuilder.new(module_configuration)

            # Prepare group queries depends on the configuration in the included
            # class.
            queries = builder.do

            # Now we have access to compiled queries to run it in aggregation
            # framework.
            module_configuration[:queries].concat(queries)
          end

          module_configuration[:reports].each do |report_name, report_configuration|
            # Lets merge report and module settings together.
            report_configuration[:fields]    = report_configuration[:fields] | module_configuration[:fields]
            report_configuration[:group_by]  = report_configuration[:group_by] | module_configuration[:group_by]
            report_configuration[:columns]   = report_configuration[:columns].merge(module_configuration[:columns])
            report_configuration[:mapping]   = report_configuration[:mapping].merge(module_configuration[:mapping])

            builder = QueriesBuilder.new(report_configuration)

            # Prepare group queries depends on the configuration in the included
            # class.
            queries = builder.do

            # Now we have access to compiled queries to run it in aggregation
            # framework.
            report_configuration[:queries].concat(queries)
          end
        end
      end
      alias :initialize :initialize_report_module

      def queries(report_module, report_name)
        report_module_settings[report_module][:reports][report_name][:queries]
      end

      def mapping(report_module, report_name)
        report_module_settings[report_module][:reports][report_name][:mapping]
      end

      def batches(report_module, report_name)
        report_module_settings[report_module][:reports][report_name][:batches]
      end

      def groups(report_module, report_name)
        report_module_settings[report_module][:reports][report_name][:group_by]
      end

      def fields(report_module, report_name)
        report_module_settings[report_module][:reports][report_name][:fields]
      end

      def columns(report_module, report_name)
        report_module_settings[report_module][:reports][report_name][:columns]
      end

      # Method for preparing of aggregation scope where you can apply query,
      # yield and other grouping methods.
      def aggregate_for(report_module, report_name)
        Scope.new(self, report_module, report_name)
      end

      def aggregate
        ScopeCollection.new(self)
      end
    end

    module ClassMethods
      def report(name, &block)
        proxy = ReportProxy.new(self, name)
        proxy.instance_eval(&block)
      end

      def attach_to(*fields, &block)
        options = fields.extract_options!
        collection = fields[0]

        options.merge!(report_name: options[:as]) if options[:as]

        define_report_method(options.merge(collection: collection)) do
          proxy = AttachProxy.new(self, collection, options)
          proxy.instance_eval(&block)
        end
      end

      def batches(*fields)
        define_report_method(*fields) do |_, report_module, report_name, batches|
          self.set_settings(report_module, report_name, :batches, batches.stringify_keys!)
        end
      end

      def filter(*fields)
        define_report_method(*fields) do |_, report_module, report_name, options|
          queries = self.get_settings(report_module, report_name, :queries)

          options.each do |key, value|
            queries
              .concat([{
                '$match' => { key => value }
              }])
          end
        end
      end

      def group_by(*fields)
        define_report_method(*fields) do |groups, report_module, report_name, _|
          self.set_settings(report_module, report_name, :group_by, groups.map(&:to_s))
        end
      end

      def column(*fields)
        define_report_method(*fields) do |columns, report_module, report_name, _|
          columns.each do |field|
            self.get_settings(report_module, report_name, :fields) << field.to_s
          end
        end
      end

      def columns(*fields)
        define_report_method(*fields) do |_, report_module, report_name, columns|
          self.set_settings(report_module, report_name, :columns, columns.stringify_keys!)
        end
      end

      def mapping(*fields)
        define_report_method(*fields) do |_, report_module, report_name, mapping|
          mapping.stringify_keys!

          mapping.each do |key, value|
            mapping[key] = value.to_s
          end

          self.set_settings(report_module, report_name, :mapping, mapping)
        end
      end

      def get_settings(report_module, report_name, field)
        unless report_name
          self.settings[report_module][field]
        else
          self.settings[report_module][:reports][report_name][field]
        end
      end

      def set_settings(report_module, report_name, field, value)
        unless report_name
          self.settings[report_module][field] = value
        else
          self.settings[report_module][:reports][report_name][field] = value
        end
      end

      private

      def define_report_method(*fields)
        options = fields.extract_options!

        # We should always specify model to attach fields, groups
        collection = options.fetch(:collection)
        options.delete(:collection)

        report_module = options.delete(:report_module)
        report_module ||= self.name

        report_name = options.delete(:report_name)
        report_name ||= Collections.name(collection)

        # We should always have for option
        initialize_settings_by(report_module, report_name, collection)

        # Because of modifying fields(usign exract options method of
        # ActiveSupport) lets pass fields to the next block with collection.
        yield fields, report_module, report_name, options || {}
      end

      def initialize_settings_by(report_module, report_name, collection)
        # Global settings for the report block
        settings[report_module] ||= settings.fetch(report_module) do
          {
            reports:   {},
            fields:    [],
            group_by:  [],
            queries:   [],
            batches:   {},
            columns:   {},
            mapping:   {},
            compiled:  false,
          }
        end

        return unless report_name

        settings[report_module][:reports][report_name] ||=
          settings[report_module][:reports].fetch(report_name) do
            {
              collection: collection,
              fields:     [],
              group_by:   [],
              queries:    [],
              batches:    {},
              columns:    {},
              mapping:    {},
              compiled:   false,
            }
          end
      end
    end

  end
end
