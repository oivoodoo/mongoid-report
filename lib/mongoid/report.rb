require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

require_relative 'report/queries_builder'
require_relative 'report/attach_proxy'

module Mongoid
  module Report
    extend ActiveSupport::Concern

    included do
      extend ClassMethods

      class_attribute :settings

      self.settings = {}

      attr_reader :queries

      def initialize
        self.class.settings.each do |klass, configuration|
          builder = QueriesBuilder.new(configuration)

          @queries = builder.do

          # Now we have access to compiled queries to run it in aggregation
          # framework.
          configuration[:queries] = queries
        end
      end

      def aggregate
        # TODO: Model.collection.aggregate(self.class.queries)
        {}
      end
    end

    module ClassMethods
      def attach_to(collection, &block)
        proxy = AttachProxy.new(self, collection)
        proxy.instance_eval(&block)
      end

      def group_by(*fields)
        define_report_method(*fields) do |groups, collection|
          settings[collection][:group_by] = groups
        end
      end

      def aggregation_field(*fields)
        define_report_method(*fields) do |columns, collection|
          columns.each do |column|
            add_field(collection, column)
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

        # We should always have for option
        initialize_settings_by(collection)

        # Because of modifying fields(usign exract options method of
        # ActiveSupport) lets pass fields to the next block with collection.
        yield fields, collection
      end

      def initialize_settings_by(collection)
        settings[collection] ||= settings.fetch(collection) do
          {
            fields:    [],
            group_by:  [],
          }
        end
      end

      def add_field(collection, field)
        settings[collection][:fields] << field

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
