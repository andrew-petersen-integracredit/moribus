module Core
  module Behaviors
    # Adds aggregated behavior to a model. An aggregated model tries to insure it will not duplicate
    # itself for whatever parents it belongs to. Whenever aggregated model is about to be saved, it
    # uses it's attributes to perform lookup of existing record with the same attributes. If lookup
    # succeeds, it's id is used to replace id of model being saved, and no 'INSERT' statement is
    # executed. If lookup fails, original AR save routines are performed.
    module AggregatedBehavior
      # specifies a list of attributes to exclude from lookup
      NON_CONTENT_COLUMNS = %w(id created_at updated_at lock_version)

      # Overrides original AR::Base #save method for aggregated behavior. This cannot be done using
      # before_save callback since if lookup succeeds, we don't want original #save to be executed,
      # but if +false+ is returned by callback, it will also be returned by #save method, Wrongly
      # indicating result of saving.
      def save(*)
        @updated_as_aggregated = false
        return (lookup_self_and_replace or super) if new_record?

        if changed?
          new_recordify
          lookup_self_and_replace or return super
        end
        true
      end

      # Uses attributes of +self+ to find existing record in table with the same attributes.
      def lookup_self
        relation = self.class.unscoped.where(attributes.except(*NON_CONTENT_COLUMNS))
        relation.first
      end
      private :lookup_self

      # If #lookup_self successfully returns a record, 'replaces' self by it (uses it's
      # id, created_at, updated_at values)
      def lookup_self_and_replace
        @updated_as_aggregated = true
        if (existing = lookup_self).present?
          persistentify(existing)
        end
      end
      private :lookup_self_and_replace
    end
  end
end
