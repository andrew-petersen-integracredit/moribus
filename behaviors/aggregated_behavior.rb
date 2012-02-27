module Core
  module Behaviors
    module AggregatedBehavior
      NON_CONTENT_COLUMNS = %w(id created_at updated_at lock_version)

      def save(*)
        @updated_as_aggregated = false
        return (lookup_self_and_replace or super) if new_record?

        if changed?
          new_recordify
          lookup_self_and_replace or return super
        end
        true
      end

      def lookup_self
        relation = self.class.unscoped.where(attributes.except(*NON_CONTENT_COLUMNS))
        relation.first
      end

      def lookup_self_and_replace
        @updated_as_aggregated = true
        if (existing = lookup_self).present?
          persistentify(existing)
        end
      end
    end
  end
end
