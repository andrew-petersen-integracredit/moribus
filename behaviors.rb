module Core
  module Behaviors
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    autoload :AggregatedBehavior
    autoload :TrackedBehavior
    autoload :Macros
    autoload :Extensions

    included do
      include Extensions
      extend Macros
    end

    module ClassMethods
      def aggregated
        include AggregatedBehavior
      end

      def tracked
        include TrackedBehavior
      end
    end

    def new_recordify
      @_id_before_new_recodify = id
      self.id = nil
      @new_record = true
    end

    def persistentify(existing = nil)
      if existing
        self.id         = existing.id
        self.created_at = existing.created_at if respond_to?(:created_at)
        self.updated_at = existing.updated_at if respond_to?(:updated_at)
        @changed_attributes = {}
      else
        self.id = @_id_before_new_recordify
      end
      @new_record = false
      true
    end

    def updated_as_aggregated?
      !!@updated_as_aggregated
    end

    def tracked?
      false
    end
  end
end
