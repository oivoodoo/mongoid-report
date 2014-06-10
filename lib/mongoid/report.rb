module Mongoid
  module Report
    extend ActiveSupport::Concern

    included do
      class_attribute :settings

      self.settings = {}

      attr_reader :queries

      include InstanceMethods
    end

    AttachProxy = Struct.new(:context, :collection) do
      def aggregation_field(*fields)
        context.aggregation_field(*fields, for: collection)
      end

      def group_by(*fields)
        context.group_by(*fields, for: collection)
      end
    end

    QueriesBuilder = Struct.new(:settings) do
      def groups
        @group_by ||= begin
          if settings[:group_by].size == 0
            [:_id]
          else
            settings[:group_by]
          end
        end
      end

      def fields
        @fields ||= settings[:fields]
      end

      def all_fields
        [:_id]
          .concat(fields)
          .concat(groups)
      end

      # Example: { '$project' => { :field1 => 1 } }
      def query1
        all_fields.inject({}) do |hash, field|
          hash.merge!(field => 1)
        end
      end

      GROUP_TEMPLATE = "$%s"
      def query2
        {}.tap do |query|
          query[:_id] = {}

          groups.inject(query[:_id]) do |hash, group|
            hash.merge!(group => GROUP_TEMPLATE % group)
          end

          fields.inject(query) do |hash, field|
            hash.merge!(field => { '$sum' => GROUP_TEMPLATE % field })
          end
        end
      end

      PROJECT_TEMPLATE = "$_id.%s"
      def query3
        {}.tap do |query|
          if groups == [:_id]
            query[:_id] = '$_id'
          else
            query[:_id] = 0

            groups.inject(query) do |hash, group|
              hash.merge!(group => PROJECT_TEMPLATE % group)
            end
          end

          fields.inject(query) do |hash, field|
            hash.merge!(field => 1)
          end
        end
      end

      def do
        [].tap do |queries|
          queries.concat([{ '$project' => query1 }])
          queries.concat([{ '$group'   => query2 }])
          queries.concat([{ '$project' => query3 }])
        end
      end
    end

    module InstanceMethods
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
