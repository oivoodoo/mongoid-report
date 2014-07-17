require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

require_relative 'report/config'
require_relative 'report/queries_builder'
require_relative 'report/attach_proxy'
require_relative 'report/collection'
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

        @report_module_settings.each do |klass, configuration|
          builder = QueriesBuilder.new(configuration)

          # Prepare group queries depends on the configuration in the included
          # class.
          @queries = builder.do

          # Now we have access to compiled queries to run it in aggregation
          # framework.
          configuration[:queries].concat(@queries)
        end
      end
      alias :initialize :initialize_report_module

      def queries(klass)
        report_module_settings[klass][:queries]
      end

      def mapping(klass)
        report_module_settings[klass][:mapping]
      end

      # We should pass here mongoid document
      def aggregate_for(report_name)
        Scope.new(self, report_name)
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

      def attach_to(collection, options = {}, &block)
        proxy = AttachProxy.new(self, collection, options)
        proxy.instance_eval(&block)
      end

      def batches(*fields)
        define_report_method(*fields) do |_, report_name, batches|
          self.settings[report_name][:batches] = batches.stringify_keys!
        end
      end

      def filter(*fields)
        define_report_method(*fields) do |_, report_name, options|
          queries = self.settings_property(report_name, :queries)

          options.each do |key, value|
            queries
              .concat([{
                '$match' => { key => value }
              }])
          end
        end
      end

      def group_by(*fields)
        define_report_method(*fields) do |groups, report_name, _|
          settings[report_name][:group_by] = groups.map(&:to_s)
        end
      end

      def column(*fields)
        define_report_method(*fields) do |columns, report_name, options|
          columns.each do |column|
            name = options.fetch(:as) { column }
            add_field(report_name, column, name)
          end
        end
      end

      def columns(*fields)
        define_report_method(*fields) do |_, report_name, columns|
          self.settings[report_name][:columns] = columns.stringify_keys!
        end
      end

      def mapping(*fields)
        define_report_method(*fields) do |_, report_name, mapping|
          mapping.stringify_keys!

          mapping.each do |key, value|
            mapping[key] = value.to_s
          end

          self.settings[report_name][:mapping] = mapping
        end
      end

      def fields(collection)
        settings_property(collection, :fields, {})
      end

      def groups(collection)
        settings_property(collection, :group_by, [])
      end

      def settings_property(collection, key, default = [])
        settings
          .fetch(collection) { {} }
          .fetch(key) { default }
      end

      private

      def define_report_method(*fields)
        options = fields.extract_options!

        # We should always specify model to attach fields, groups
        collection = options.fetch(:for)
        options.delete(:for)

        # If user didn't pass as option to name the report we are using
        # collection class as key for settings.
        attach_name = options.fetch(:attach_name) { collection }
        options.delete(:attach_name)

        # We should always have for option
        initialize_settings_by(attach_name, collection)

        # Because of modifying fields(usign exract options method of
        # ActiveSupport) lets pass fields to the next block with collection.
        yield fields, attach_name, options || {}
      end

      def initialize_settings_by(attach_name, collection)
        settings[attach_name] ||= settings.fetch(attach_name) do
          {
            for:       collection,
            fields:    ActiveSupport::OrderedHash.new,
            group_by:  [],
            queries:   [],
            columns:   {},
            mapping:   {},
            compiled:  false,
          }
        end
      end

      def add_field(attach_name, field, name)
        settings[attach_name][:fields][field.to_s] = name.to_s
      end
    end

  end
end
