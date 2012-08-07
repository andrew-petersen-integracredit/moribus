module Core
  module Behaviors
    module AggregatedCacheBehavior
      extend ActiveSupport::Concern

      # Raised when trying to include module to non-aggregated model
      NotAggregatedError = Class.new(::ArgumentError)

      included do
        unless self < AggregatedBehavior
          raise NotAggregatedError, 'AggregatedCache can be used only in Aggregated models'
        end

        class_attribute :aggregated_records_cache
        self.aggregated_records_cache = {}

        after_save :cache_aggregated_record, :on => :create
      end

      module ClassMethods
        # Empty cache of aggregated records
        def clear_cache
          self.aggregated_records_cache = {}
        end

        # Return column (attribute), value of which is used
        # as key for caching records
        def aggregated_caching_column
          @aggregated_caching_column
        end
      end

      # Overridden for caching support
      def lookup_self
        cache = self.class.aggregated_records_cache
        cache_by = caching_attribute
        return cache[cache_by] if cache.key? cache_by
        lookup_result = super
        cache[cache_by] = lookup_result if lookup_result
        lookup_result
      end
      private :lookup_self

      # Cache record.
      def cache_aggregated_record
        cache_by = caching_attribute
        self.class.aggregated_records_cache[cache_by] = dup.tap{ |d| d.to_persistent!(self); d.freeze }
      end
      private :cache_aggregated_record

      # Return the value of caching column (attribute) used as
      # key of records cache
      def caching_attribute
        read_attribute(self.class.aggregated_caching_column)
      end
      private :caching_attribute
    end
  end
end
