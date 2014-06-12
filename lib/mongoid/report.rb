require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

require_relative 'report/queries_builder'
require_relative 'report/attach_proxy'
require_relative 'report/collection'

module Mongoid
  module Report
    extend ActiveSupport::Concern

    included do
      extend ClassMethods

      class_attribute :settings

      self.settings = {}

      def initialize_report_module
        self.class.settings.each do |klass, configuration|
          builder = QueriesBuilder.new(configuration)

          # Prepare group queries depends on the configuration in the included
          # class.
          @queries = builder.do

          # Now we have access to compiled queries to run it in aggregation
          # framework.
          configuration[:queries] = @queries
        end
      end
      alias :initialize :initialize_report_module

      def queries(klass)
        self.class.settings[klass][:queries]
      end

      # We should pass here mongoid document
      def aggregate_for(klass)
        queries = queries(klass)

        yield queries if block_given?

        # Lets wrap aggregation by collection structure for adding common
        # methods like summary for data.
        Collection.new(
          klass.collection.aggregate(queries),
          self.class.fields(klass),
        )
      end
    end

    module ClassMethods
      def attach_to(collection, options = {}, &block)
        proxy = AttachProxy.new(self, collection, options)
        proxy.instance_eval(&block)
      end

      def group_by(*fields)
        define_report_method(*fields) do |groups, report_name|
          settings[report_name][:group_by] = groups
        end
      end

      def aggregation_field(*fields)
        define_report_method(*fields) do |columns, report_name|
          columns.each do |column|
            add_field(report_name, column)
          end
        end
      end

      def fields(collection)
        settings_property(collection, :fields)
      end

      def groups(collection)
        settings_property(collection, :group_by)
      end

      private

      def define_report_method(*fields)
        options = fields.extract_options!

        # We should always specify model to attach fields, groups
        collection = options.fetch(:for)

        # If user didn't pass as option to name the report we are using
        # collection class as key for settings.
        report_name = options.fetch(:as) { collection }

        # We should always have for option
        initialize_settings_by(report_name)

        # Because of modifying fields(usign exract options method of
        # ActiveSupport) lets pass fields to the next block with collection.
        yield fields, report_name
      end

      def initialize_settings_by(report_name)
        settings[report_name] ||= settings.fetch(report_name) do
          {
            fields:    [],
            group_by:  [],
          }
        end
      end

      def add_field(report_name, field)
        settings[report_name][:fields] << field

        class_eval <<-FIELD
          def #{field}
            @#{field} ||= 0
          end
        FIELD
      end

      def settings_property(collection, key)
        settings.fetch(collection, {}).fetch(key, [])
      end
    end

  end
end
